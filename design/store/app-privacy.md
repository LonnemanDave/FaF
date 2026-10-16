# App Store Connect — App Privacy answers

Left sidebar → **App Privacy** (app-level, not version-level). Must be completed
by an Account Holder or Admin and then **Published** — answering without
publishing leaves Submit greyed out.

**Privacy Policy URL:** `https://faf-1-93659.web.app/privacy`

**Do you or your third-party partners collect data from this app?** → **Yes**

## Collected, LINKED to the user, for App Functionality — not used for tracking

| Data type | Why |
|---|---|
| Contact Info → Email Address | Firebase Auth account (or Apple's relay address) |
| Contact Info → Name | optional display name on the profile |
| User Content → Photos or Videos | recipe photos and the optional profile photo, in Firebase Storage |
| User Content → Other User Content | recipes, variations/notes, menus, shopping lists, friend requests, activity entries, reports |
| Identifiers → User ID | Firebase UID and username, the key for every record |
| Location → Coarse Location | the city/state text on the profile (see below) |

For each of these: **Purpose → App Functionality only.** Not Analytics, not
Advertising, not Product Personalization. **Linked to identity → Yes.**
**Used for tracking → No.**

Reports are also used for moderation; App Store Connect has no separate
"moderation" purpose, and App Functionality covers it.

## Tracking

**No.** No advertising, no ad networks, no analytics or tracking SDKs, no data
brokers, no cross-app tracking, no ATT prompt, no IDFA.

## Not collected

- **Precise Location** — "Find me" reads the location once and turns it into a
  city and state with Apple's geocoder (CLGeocoder); the coordinates are never
  saved or sent to Firebase.
- **Diagnostics** — there is no Crashlytics or analytics SDK in the app. Crash
  logs Apple forwards from users who opted in to share with developers don't
  count as collection by the app.
- **Purchases, Financial Info, Health & Fitness, Contacts, Browsing/Search
  History, Sensitive Info** — none.
- **Search History** — Kroger search terms go from the phone directly to
  Kroger's API and are not stored by us. (Matched products are saved on the
  shopping list, which is already declared as Other User Content.)

## Judgment calls

**Coarse Location.** Coordinates aren't collected, but the profile does store a
city and state that the user can fill in with "Find me". Declaring
**Location → Coarse Location, linked, App Functionality** is the safe reading.
Over-disclosure costs nothing; under-disclosure is what gets apps pulled. If you
prefer, the narrower defensible reading is that it's user-typed profile text
(Other User Content) — but declare it.

**Kroger store.** The chosen Kroger store (location ID and name) is saved on the
profile. It's a store, not the user's position; covered by Other User Content.

**Sign in with Apple / Google.** Email and a user identifier from the sign-in
provider are already covered by Email Address and User ID.

## Age Rating (App Information → Age Rating → Edit) — see checklist.md

## Content Rights (App Information → Content Rights Information)

**Does your app contain, display, or access third-party content?** → **Yes.**
Kroger product names, images and prices come from Kroger's public product API,
and the app displays user-generated content. Confirm you have the rights to use
it under the Kroger developer terms.
