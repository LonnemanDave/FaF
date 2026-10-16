/**
 * Food & Friends server functions.
 *
 * The Kroger keys live here so the client secret never ships inside the app.
 * The client ID (public) is in functions/.env with KROGER_API_BASE; the
 * secret is in Secret Manager, set once with a command that prompts for it:
 *
 *   firebase functions:secrets:set KROGER_CLIENT_SECRET
 */
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";
import { setGlobalOptions } from "firebase-functions/v2";
import { issueToken, KrogerError } from "./kroger";
import { deleteUserData, deleteAuthUser } from "./account";

const krogerClientId = defineString("KROGER_CLIENT_ID");
const krogerClientSecret = defineSecret("KROGER_CLIENT_SECRET");
/** Certification keys answer at https://api-ce.kroger.com/v1; production at https://api.kroger.com/v1. */
const krogerApiBase = defineString("KROGER_API_BASE");

// A cook's journal, not a storefront: a couple of instances is plenty, and caps the bill.
setGlobalOptions({ region: "us-central1", maxInstances: 2 });

/**
 * A short-lived Kroger access token for the signed-in app, which then calls
 * Kroger itself. `{ api: "products" | "locations" }` →
 * `{ accessToken, expiresIn, apiBase }`
 */
export const krogerToken = onCall({ secrets: [krogerClientSecret], timeoutSeconds: 30 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to use Kroger.");
  }
  const api = request.data?.api;
  if (api !== "products" && api !== "locations") {
    throw new HttpsError("invalid-argument", "Ask for a products or locations token.");
  }

  const clientId = krogerClientId.value();
  const clientSecret = krogerClientSecret.value();
  if (!clientId || !clientSecret) {
    throw new HttpsError("failed-precondition", "The Kroger keys haven't been set up yet.");
  }
  const apiBase = krogerApiBase.value();

  try {
    const token = await issueToken({ clientId, clientSecret, apiBase }, api === "products" ? "product.compact" : undefined);
    return {
      accessToken: token.accessToken,
      expiresIn: Math.max(0, Math.floor((token.expiresAt - Date.now()) / 1000)),
      apiBase,
    };
  } catch (error) {
    if (error instanceof KrogerError) {
      console.warn(error.message); // which step, and Kroger's reason — never the keys
      throw new HttpsError("failed-precondition", "Kroger turned the keys down. Check the client ID and secret.");
    }
    console.error(error);
    throw new HttpsError("internal", "Something went wrong signing in to Kroger.");
  }
});

/**
 * Deletes the signed-in cook's account and everything they put in the
 * journal: profile, recipes (with their variations), variations on friends'
 * recipes, menus, shopping lists, feed entries, friend requests, their place
 * in friends' lists, and their photos — then the sign-in itself. Reports are
 * kept for moderation. No arguments → `{ success: true }`
 */
export const deleteAccount = onCall({ timeoutSeconds: 300 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in to delete your account.");
  }

  try {
    await deleteUserData(uid);
    await deleteAuthUser(uid);
  } catch (error) {
    console.error(`deleteAccount: failed for ${uid}`, error);
    throw new HttpsError("internal", "Your account couldn't be deleted just now. Please try again.");
  }

  console.log(`deleteAccount: removed user ${uid}`);
  return { success: true };
});
