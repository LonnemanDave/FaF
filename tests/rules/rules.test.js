/* Rules tests: the app's own reads and writes, run against firestore.rules.
 *
 * Each test is something the app actually does — the exact query shape,
 * the exact batch — because a rule that's right in principle can still
 * refuse the app's query (rules aren't filters) or fail an atomic batch.
 *
 * Run: cd tests/rules && npm install && npm test   (needs Java for the emulator)
 */

import { readFileSync } from "node:fs";
import { test, before, after, beforeEach, describe } from "node:test";
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc, getDocs, collection, query, where, orderBy,
  writeBatch, arrayUnion, arrayRemove, increment, serverTimestamp,
} from "firebase/firestore";

// Ann and Ben are friends. Cal is a stranger to both.
const ANN = "ann", BEN = "ben", CAL = "cal";
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "faf-rules-test",
    firestore: {
      rules: readFileSync(new URL("../../firestore.rules", import.meta.url), "utf8"),
      host: "127.0.0.1",
      port: 8181,
    },
  });
});

after(async () => { await env?.cleanup(); });

const now = new Date();
const user = (uid, friends = []) => ({ email: `${uid}@example.com`, username: uid, location: "Cincinnati, OH", friends, createdAt: now, updatedAt: now });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users", ANN), user(ANN, [BEN]));
    await setDoc(doc(db, "users", BEN), user(BEN, [ANN]));
    await setDoc(doc(db, "users", CAL), user(CAL));
    await setDoc(doc(db, "recipes", "benPrivate"), { authorId: BEN, title: "Ben's stew", isPublic: false, createdAt: now });
    await setDoc(doc(db, "recipes", "benPublic"), { authorId: BEN, title: "Ben's bread", isPublic: true, createdAt: now });
    await setDoc(doc(db, "recipes", "calPrivate"), { authorId: CAL, title: "Cal's chili", isPublic: false, createdAt: now });
    await setDoc(doc(db, "recipes", "benPrivate", "variations", "annTake"), { authorId: ANN, notes: "more thyme", likeCount: 0, createdAt: now });
    await setDoc(doc(db, "mealPlans", "benWeek"), { authorId: BEN, name: "Week", createdAt: now });
    await setDoc(doc(db, "activities", "benEntry"), { authorId: BEN, type: "newRecipe", createdAt: now });
    await setDoc(doc(db, "shoppingLists", "benList"), { authorId: BEN, items: [], createdAt: now });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();

describe("recipes", () => {
  test("a friend reads a private recipe; a stranger can't", async () => {
    await assertSucceeds(getDoc(doc(as(ANN), "recipes", "benPrivate")));
    await assertFails(getDoc(doc(as(CAL), "recipes", "benPrivate")));
  });

  test("anyone reads a recipe shared with everyone", async () => {
    await assertSucceeds(getDoc(doc(as(CAL), "recipes", "benPublic")));
  });

  test("the Friends shelf: authorId in [friends], newest first", async () => {
    const q = query(collection(as(ANN), "recipes"), where("authorId", "in", [BEN]), orderBy("createdAt", "desc"));
    await assertSucceeds(getDocs(q));
  });

  test("the Friends shelf refuses a list padded with a stranger", async () => {
    const q = query(collection(as(ANN), "recipes"), where("authorId", "in", [BEN, CAL]), orderBy("createdAt", "desc"));
    await assertFails(getDocs(q));
  });

  test("the Everyone shelf: isPublic == true", async () => {
    const q = query(collection(as(CAL), "recipes"), where("isPublic", "==", true), orderBy("createdAt", "desc"));
    await assertSucceeds(getDocs(q));
  });

  test("a stranger's profile page asks only for what's public", async () => {
    const pub = query(collection(as(CAL), "recipes"), where("authorId", "in", [BEN]), where("isPublic", "==", true));
    await assertSucceeds(getDocs(pub));
    const all = query(collection(as(CAL), "recipes"), where("authorId", "in", [BEN]));
    await assertFails(getDocs(all));
  });

  test("you can only write recipes as yourself, and only change your own", async () => {
    await assertSucceeds(addDoc(collection(as(ANN), "recipes"), { authorId: ANN, title: "Soup", isPublic: false, createdAt: now }));
    await assertFails(addDoc(collection(as(ANN), "recipes"), { authorId: BEN, title: "Forged", isPublic: true, createdAt: now }));
    await assertFails(updateDoc(doc(as(ANN), "recipes", "benPrivate"), { title: "Mine now" }));
  });
});

describe("variations", () => {
  test("a friend reads and likes a variation; a stranger can't", async () => {
    await assertSucceeds(getDoc(doc(as(BEN), "recipes", "benPrivate", "variations", "annTake")));
    await assertFails(getDoc(doc(as(CAL), "recipes", "benPrivate", "variations", "annTake")));
    await assertSucceeds(updateDoc(doc(as(BEN), "recipes", "benPrivate", "variations", "annTake"), { likeCount: increment(1) }));
    await assertFails(updateDoc(doc(as(CAL), "recipes", "benPrivate", "variations", "annTake"), { likeCount: increment(1) }));
  });

  test("liking can't rewrite the note or jump the count", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "recipes", "benPublic", "variations", "calTake"), { authorId: CAL, notes: "x", likeCount: 0 });
    });
    await assertFails(updateDoc(doc(as(ANN), "recipes", "benPublic", "variations", "calTake"), { notes: "rewritten" }));
    await assertFails(updateDoc(doc(as(ANN), "recipes", "benPublic", "variations", "calTake"), { likeCount: 50 }));
  });

  test("the app's 'have I already written one?' query", async () => {
    const q = query(collection(as(ANN), "recipes", "benPrivate", "variations"), where("authorId", "==", ANN));
    await assertSucceeds(getDocs(q));
  });
});

describe("menus, the Table, shopping lists", () => {
  test("menus and Table entries: friends yes, strangers no", async () => {
    await assertSucceeds(getDoc(doc(as(ANN), "mealPlans", "benWeek")));
    await assertFails(getDoc(doc(as(CAL), "mealPlans", "benWeek")));
    await assertSucceeds(getDoc(doc(as(ANN), "activities", "benEntry")));
    await assertFails(getDoc(doc(as(CAL), "activities", "benEntry")));
  });

  test("the Table's query: authorId in [friends], newest first", async () => {
    const q = query(collection(as(ANN), "activities"), where("authorId", "in", [BEN]), orderBy("createdAt", "desc"));
    await assertSucceeds(getDocs(q));
    const menus = query(collection(as(ANN), "mealPlans"), where("authorId", "in", [BEN]), orderBy("createdAt", "desc"));
    await assertSucceeds(getDocs(menus));
  });

  test("a shopping list is its owner's alone", async () => {
    await assertSucceeds(getDocs(query(collection(as(BEN), "shoppingLists"), where("authorId", "==", BEN))));
    await assertFails(getDoc(doc(as(ANN), "shoppingLists", "benList")));
  });
});

describe("friends", () => {
  test("send, then accept — the app's batch", async () => {
    await assertSucceeds(setDoc(doc(as(CAL), "friendRequests", `${CAL}_${ANN}`),
      { fromUserId: CAL, toUserId: ANN, status: "pending", createdAt: now }));

    const db = as(ANN);
    const batch = writeBatch(db);
    batch.update(doc(db, "friendRequests", `${CAL}_${ANN}`), { status: "accepted" });
    batch.update(doc(db, "users", CAL), { friends: arrayUnion(ANN), updatedAt: now });
    batch.update(doc(db, "users", ANN), { friends: arrayUnion(CAL), updatedAt: now });
    await assertSucceeds(batch.commit());
  });

  test("a stranger can't put themselves on your friends list", async () => {
    await assertFails(updateDoc(doc(as(CAL), "users", ANN), { friends: arrayUnion(CAL), updatedAt: now }));
  });

  test("…not even by accepting a request they made up", async () => {
    // Cal can't file a request "from Ann"
    await assertFails(setDoc(doc(as(CAL), "friendRequests", `${ANN}_${CAL}`),
      { fromUserId: ANN, toUserId: CAL, status: "accepted", createdAt: now }));
    // nor accept their own request to Ann
    await setDoc(doc(as(CAL), "friendRequests", `${CAL}_${ANN}`), { fromUserId: CAL, toUserId: ANN, status: "pending", createdAt: now });
    await assertFails(updateDoc(doc(as(CAL), "friendRequests", `${CAL}_${ANN}`), { status: "accepted" }));
  });

  test("a request must carry its {from}_{to} id", async () => {
    await assertFails(addDoc(collection(as(CAL), "friendRequests"), { fromUserId: CAL, toUserId: ANN, status: "pending", createdAt: now }));
  });

  test("only the two people in a request can see it", async () => {
    await setDoc(doc(as(CAL), "friendRequests", `${CAL}_${ANN}`), { fromUserId: CAL, toUserId: ANN, status: "pending", createdAt: now });
    await assertSucceeds(getDoc(doc(as(ANN), "friendRequests", `${CAL}_${ANN}`)));
    await assertFails(getDoc(doc(as(BEN), "friendRequests", `${CAL}_${ANN}`)));
    await assertSucceeds(getDocs(query(collection(as(ANN), "friendRequests"), where("toUserId", "==", ANN), where("status", "==", "pending"))));
  });

  test("unfriending takes you off both lists — the app's batch", async () => {
    const db = as(ANN);
    const batch = writeBatch(db);
    batch.update(doc(db, "users", ANN), { friends: arrayRemove(BEN), updatedAt: now });
    batch.update(doc(db, "users", BEN), { friends: arrayRemove(ANN), updatedAt: now });
    await assertSucceeds(batch.commit());
  });

  test("you can't take someone else off a third person's list", async () => {
    await assertFails(updateDoc(doc(as(CAL), "users", ANN), { friends: arrayRemove(BEN), updatedAt: now }));
  });
});

describe("blocking", () => {
  test("block — the app's batch, including clearing requests both ways", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "friendRequests", `${BEN}_${ANN}`), { fromUserId: BEN, toUserId: ANN, status: "declined", createdAt: now });
    });
    const db = as(ANN);
    const batch = writeBatch(db);
    batch.set(doc(db, "users", ANN, "blocked", BEN), { blockedAt: now });
    batch.update(doc(db, "users", ANN), { friends: arrayRemove(BEN), updatedAt: now });
    batch.update(doc(db, "users", BEN), { friends: arrayRemove(ANN), updatedAt: now });
    batch.delete(doc(db, "friendRequests", `${BEN}_${ANN}`));
    await assertSucceeds(batch.commit());

    // and with that, Ben can no longer see Ann's private things
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "recipes", "annPrivate"), { authorId: ANN, isPublic: false, createdAt: now });
    });
    await assertFails(getDoc(doc(as(BEN), "recipes", "annPrivate")));
  });

  test("a blocked cook can't send a request, or re-send an old one", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, "users", ANN, "blocked", CAL), { blockedAt: now });
      await setDoc(doc(db, "friendRequests", `${CAL}_${ANN}`), { fromUserId: CAL, toUserId: ANN, status: "declined", createdAt: now });
    });
    await assertFails(setDoc(doc(as(CAL), "friendRequests", `${CAL}_${ANN}`), { fromUserId: CAL, toUserId: ANN, status: "pending", createdAt: now }));
  });

  test("…or slip onto the list through an old accepted request", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, "friendRequests", `${ANN}_${CAL}`), { fromUserId: ANN, toUserId: CAL, status: "accepted", createdAt: now });
      await setDoc(doc(db, "users", ANN, "blocked", CAL), { blockedAt: now });
    });
    await assertFails(updateDoc(doc(as(CAL), "users", ANN), { friends: arrayUnion(CAL), updatedAt: now }));
  });

  test("your blocked list is yours alone", async () => {
    await assertSucceeds(getDocs(collection(as(ANN), "users", ANN, "blocked")));
    await assertFails(getDocs(collection(as(BEN), "users", ANN, "blocked")));
    await assertFails(setDoc(doc(as(BEN), "users", ANN, "blocked", CAL), { blockedAt: now }));
  });
});

describe("reports", () => {
  const report = (reporterId) => ({
    reporterId, targetType: "recipe", targetId: "benPublic", targetUserId: BEN,
    reason: "Spam or advertising", note: "", status: "open", createdAt: serverTimestamp(),
  });

  test("anyone can file one, as themselves", async () => {
    await assertSucceeds(addDoc(collection(as(CAL), "reports"), report(CAL)));
    await assertFails(addDoc(collection(as(CAL), "reports"), report(ANN)));
  });

  test("…and nobody can read, change or withdraw one", async () => {
    const ref = await addDoc(collection(as(CAL), "reports"), report(CAL));
    await assertFails(getDoc(doc(as(CAL), "reports", ref.id)));
    await assertFails(getDoc(doc(as(BEN), "reports", ref.id)));
    await assertFails(updateDoc(doc(as(CAL), "reports", ref.id), { note: "never mind" }));
    await assertFails(deleteDoc(doc(as(CAL), "reports", ref.id)));
  });

  test("a report must say what it's about", async () => {
    await assertFails(addDoc(collection(as(CAL), "reports"), { ...report(CAL), targetType: "everything" }));
    await assertFails(addDoc(collection(as(CAL), "reports"), { ...report(CAL), note: "x".repeat(1001) }));
  });
});
