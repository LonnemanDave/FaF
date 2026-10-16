# Screen recording script — App Review

One continuous take on a physical iPhone, on the build you're submitting.
Target about 5 minutes. Every beat below is something App Review asks to see for
an app with accounts and user-generated content.

The order matters: a throwaway account is registered first and deleted
straight after, which demonstrates registration, terms acceptance *and* account
deletion without touching the demo account — and leaves you signed out, ready
to sign in as the reviewer would.

## Before you press record

- **Settings → General → Transfer or Reset iPhone → Reset → Reset Location &
  Privacy**, so the location prompt appears when you tap "Find me" in beat 2.
- **Do Not Disturb on.** A banner sliding over the app mid-take means starting
  again.
- The **second test account** (the demo account's friend) has at least one
  recipe and one Table entry, so there is something to report and someone to
  block.
- Have the throwaway address ready, e.g. `david.lonneman+faf-rec1@gmail.com`.
- Have a ZIP ready with a Kroger-family store, e.g. `45202`.
- Be **signed out**, then go to the **home screen**, so beat 1 is a cold launch.

Start the recording from Control Centre, then wait two seconds on the home
screen before touching anything.

## The beats

**1 — Cold launch** (0:00)
Tap Food & Friends on the home screen. Let the launch screen finish. Don't
resume from the app switcher.

**2 — Sign up, with terms** (0:10)
Create an account with the throwaway email and a password. **Show the Terms of
Use acceptance** — pause on it so the zero-tolerance line is readable, tap the
link if there is one, then accept. Pick a username. Tap **Find me** → the iOS
location prompt → Allow → show the city fill in. Land on Home; pause on the
empty journal for a beat — an empty state is proof it's a new account.

**3 — Delete the throwaway account** (1:00)
MORE → YOU → **Delete account** → confirm. Show it return to the sign-in
screen. Done here, on the throwaway, so the demo account survives.

**4 — Sign in with the demo account** (1:20)
DEMO EMAIL / DEMO PASSWORD. Land on Home with real content. Hold still for
three seconds so they can read it.

**5 — Write a recipe** (1:35)
RECIPES → write a new recipe → title, a few ingredients, a step or two → add a
photo from the library → choose who sees it → save. Show it in the recipe box.

**6 — Add it to the shopping list** (2:15)
From the recipe, add its ingredients to the shopping list. Switch to SHOPPING
and show the lines, labelled with the recipe they came from.

**7 — Kroger store and matching** (2:35)
SHOPPING → the Kroger section → pick a store by ZIP (`45202`) → choose a store.
Tap a line → pick its product (show the price). Optionally **Match all**. Say
nothing; the notes explain it's Kroger's public API and needs no account.

**8 — Plan a menu** (3:15)
MORE → MENUS → plan a week by hand → put a recipe on a day → save. Show the
menu.

**9 — The Table** (3:45)
MORE → TABLE. Show the friend's entries.

**10 — Report an entry and a recipe** (4:00) — *the part they care most about*
- **Press and hold a Table entry → Report** → pick a reason → send → show the
  confirmation.
- Open one of the friend's recipes → **⋯ → Report** → pick a reason → send →
  the confirmation.

**11 — Block a person** (4:40)
Open the friend's profile → **Block** → confirm → go back to The Table and
**show their entries are gone**. That last step is the one that answers
guideline 1.2. Don't rush it.

Stop recording. Attach the file to the Resolution Center reply, or host it
somewhere shareable and paste the URL — Apple accepts either.

## Afterwards

- **Unblock the friend** you blocked in beat 11 and re-add them if blocking
  ended the friendship. Otherwise the demo account the reviewer signs into has
  an empty Table, which looks like a bug.
- In the Firestore console, **resolve or delete the test reports** from beat
  10 so they don't sit in the moderation queue.
- Delete the recipe and menu from beats 5 and 8 if you want the demo account
  back to its starting state (optional).
