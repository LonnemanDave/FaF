/**
 * Signing in to Kroger with the app's keys.
 *
 * This is all the server does for Kroger. Kroger's firewall turns away
 * product and store requests from Google Cloud's network, so the app makes
 * those calls itself, from the phone — using a short-lived access token it
 * gets from here. The client secret never leaves the server; a token is
 * good for one kind of request for about half an hour.
 */

export interface Credentials {
  clientId: string;
  clientSecret: string;
  /** Which Kroger environment the keys belong to. */
  apiBase: string;
}

export interface Token {
  accessToken: string;
  expiresAt: number;
}

export class KrogerError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

const tokens = new Map<string, Token>();

/**
 * A client-credentials token, kept until a few minutes before it lapses so
 * the phone always gets one with time left on it. `product.compact` for
 * products; no scope for locations, which has none of its own.
 */
export async function issueToken(credentials: Credentials, scope?: string): Promise<Token> {
  const key = `${credentials.apiBase}|${scope ?? ""}`;
  const cached = tokens.get(key);
  if (cached && cached.expiresAt > Date.now() + 5 * 60_000) return cached;

  const body = new URLSearchParams({ grant_type: "client_credentials" });
  if (scope) body.set("scope", scope);
  const basic = Buffer.from(`${credentials.clientId}:${credentials.clientSecret}`).toString("base64");

  const response = await fetch(`${credentials.apiBase}/connect/oauth2/token`, {
    method: "POST",
    headers: { Authorization: `Basic ${basic}`, "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!response.ok) {
    throw new KrogerError(`Kroger sign-in failed (${response.status}): ${await reason(response)}`, response.status);
  }
  const json = (await response.json()) as { access_token: string; expires_in: number };
  const token = { accessToken: json.access_token, expiresAt: Date.now() + json.expires_in * 1000 };
  tokens.set(key, token);
  return token;
}

/** Kroger's own explanation of a refusal, from the response body — which never carries the keys. */
async function reason(response: Response): Promise<string> {
  const text = await response.text().catch(() => "");
  try {
    const json = JSON.parse(text) as { error?: string; error_description?: string };
    return [json.error, json.error_description].filter(Boolean).join(" — ") || text.slice(0, 200);
  } catch {
    return text.slice(0, 200);
  }
}
