# App Store Connect — submission checklist (Food & Friends)

Bundle ID `com.foodandfriends.app` · iPhone only · Firebase project
`faf-1-93659`.

## Before anything else

> **AI assistant is switched off for v1** (`AIService.isEnabled = false`): no
> screens, no settings line, and no mention in the store or web copy. To turn it
> back on later, first restore the AI sections in the privacy policy, terms,
> `review-notes.txt` and the App Privacy answers (`app-privacy.md`).

- [ ] **Deploy the hosting site** (`firebase deploy --only hosting`) and open
      each URL on a phone, light and dark:
      - https://faf-1-93659.web.app/privacy
      - https://faf-1-93659.web.app/terms
      - https://faf-1-93659.web.app/support
- [ ] **Kroger production API approval.** The app currently uses Kroger's
      *Certification* environment and keys. Apply for production access on
      developer.kroger.com, switch the client ID/secret and base URL to
      production, and confirm store search and product matching still work
      **before** submitting the release build. A reviewer hitting
      certification data (or a certification outage) is a 2.1 rejection.
- [ ] Moderation is in the build you're submitting: report on a Table entry
      (press and hold), ⋯ → Report on recipes and profiles, Block on profiles,
      Terms of Use acceptance at sign-up. Without all of these, the Table is a
      guideline 1.2 rejection.
- [ ] Someone is watching the reports. The terms promise action within about
      24 hours — check the reports collection (or set up an email alert) every
      day while the app is in review and after release.

## App Information

- [ ] **Category:** Food & Drink (secondary: Lifestyle, optional).
- [ ] **Privacy Policy URL:** `https://faf-1-93659.web.app/privacy`
- [ ] **Content Rights:** contains third-party content → **Yes** (Kroger
      product data and images; user-generated content).
- [ ] **Age Rating** (Edit):
      - Violence, sexual content, nudity, profanity, horror, mature themes,
        alcohol/tobacco/drugs references, simulated gambling, contests,
        medical/treatment information → **None**.
      - **Unrestricted Web Access → No.** Links open in Safari; there is no
        in-app browser.
      - **User-Generated Content → Yes.** **Messaging and Chat → No** (there is
        no direct messaging). Social features → Yes (friends, The Table).
      - Expect **12+ / 13+** under the current age-rating scheme because of
        user-generated content. Accept whichever the questionnaire computes;
        don't understate UGC to get a lower rating.
- [ ] **App Privacy:** answer and **Publish** per `app-privacy.md`.

## Pricing and Availability

- [ ] Price → **Free**. Availability → United States is the meaningful market
      (Kroger is US-only); the rest of the app works anywhere, so all
      territories is fine.

## Version page

- [ ] **Screenshots: 6.9" iPhone only** (1320 × 2868 or 1290 × 2796). The app is
      iPhone-only, so no iPad screenshots. Don't lead with the sign-in screen
      (2.3.3) — lead with a recipe, the shopping list matched at Kroger, a
      week's menu, The Table.
- [ ] **Promotional text:** `promo.txt` (≤ 170 chars).
- [ ] **Description:** `description.txt` (≤ 4000 chars).
- [ ] **Keywords:** `keywords.txt` (≤ 100 chars). No competitor or trademark
      names in keywords (2.3.7) — "Kroger" is deliberately left out.
- [ ] **Support URL:** `https://faf-1-93659.web.app/support`
- [ ] **Marketing URL** (optional): `https://faf-1-93659.web.app`
- [ ] **Copyright:** `2026 David Lonneman`
- [ ] **Build** selected, and the build's **export compliance** is already
      answered — `ITSAppUsesNonExemptEncryption = NO` is set in the app's
      Info.plist (via `project.yml`), so no questions appear. The app only uses
      HTTPS and Apple's keychain.

## App Review Information

- [ ] **Sign-in required → Yes**, with the demo account below.
- [ ] **Contact:** David Lonneman, david.lonneman@gmail.com, a phone number.
- [ ] **Notes:** paste `review-notes.txt`, with the demo email and password
      filled in.
- [ ] **Attachment:** the screen recording from `recording-script.md`
      (optional on a first submission, but it heads off the usual 2.1 "show us
      the UGC moderation" request).

### Creating the demo account

Do this on a real build signed in against production Firebase, not the design
harness.

1. **Sign up in the app** with email and password, e.g.
   `david.lonneman+fafreview@gmail.com` and a password you'll paste into App
   Store Connect. Accept the terms, pick a username (e.g. `appreview`), type a
   city.
2. **Write two or three recipes**, at least **one with a photo**. Make one
   shared with everyone and one kept among friends. Add a variation/note to
   one of them.
3. **Plan a menu** for the current week with a couple of those recipes.
4. **Build a shopping list** — add a recipe's ingredients plus a line of your
   own. Pick a Kroger store (ZIP `45202` works) and match a couple of lines.
5. **Make a second test account** (e.g. `david.lonneman+fafreview2@gmail.com`)
   on another device or after signing out. Give it a recipe and a menu so it
   has Table entries.
6. **Befriend the two accounts** (send from one, accept on the other), then
   check that the demo account's **Table** shows the second account's entries.
   This is the account the reviewer will report and block.
7. Sign out and back in once to confirm the password, then put the
   credentials into **Sign-In Required** and into `review-notes.txt`.

## Before you press Submit

- [ ] Fresh install on a physical iPhone: sign up, sign in with Apple, sign in
      with Google, Forgot password, Delete account — all work against
      production.
- [ ] Location prompt text reads correctly (Find me during setup) and the app
      works when it's denied.
- [ ] Turn off NordVPN before installing to the device.
