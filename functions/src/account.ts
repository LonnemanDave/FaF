/**
 * Account deletion (App Store guideline 5.1.1(v)).
 *
 * Runs with admin privileges so the app needs no recent-login reauth, and so
 * it can reach the cook's traces in other people's documents (friend lists,
 * variations on friends' recipes) that the rules won't let the client touch.
 *
 * Kept on purpose: `reports` — moderation records must outlive the account.
 */
import { getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue, DocumentReference } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

if (getApps().length === 0) initializeApp();

/** Firestore allows 500 writes a batch; stay well under it. */
const BATCH_SIZE = 400;

/** Where the app keeps uploads — see StorageService.swift / RecipeDetailView.swift. */
const PROFILE_IMAGE = (uid: string) => `profile_images/${uid}.jpg`;
/** Recipe photos: `recipe_images/{recipeId}_{timestamp}.jpg`. */
const RECIPE_IMAGE_PREFIX = (recipeId: string) => `recipe_images/${recipeId}_`;
/** Variation photos: `recipe_images/variation_{variationId}_{timestamp}.jpg`. */
const VARIATION_IMAGE_PREFIX = (variationId: string) => `recipe_images/variation_${variationId}_`;

export async function deleteUserData(uid: string): Promise<void> {
  const db = getFirestore();

  // Photo prefixes to sweep once the documents are gone. Collected first,
  // while the recipe and variation IDs can still be read.
  const storagePrefixes: string[] = [];

  // 1. Recipes the cook owns, with every variation hanging off them (theirs
  //    and friends') — recursiveDelete takes the `variations` subcollection.
  const recipes = await db.collection("recipes").where("authorId", "==", uid).get();
  const ownedRecipeIds = new Set(recipes.docs.map((doc) => doc.id));
  for (const recipe of recipes.docs) {
    storagePrefixes.push(RECIPE_IMAGE_PREFIX(recipe.id));
    const variations = await recipe.ref.collection("variations").listDocuments();
    variations.forEach((v) => storagePrefixes.push(VARIATION_IMAGE_PREFIX(v.id)));
  }
  for (const recipe of recipes.docs) {
    await db.recursiveDelete(recipe.ref);
  }

  // 2. Variations the cook wrote on other people's recipes.
  //    Needs the collection-group authorId index (firestore.indexes.json).
  const theirVariations = await db.collectionGroup("variations").where("authorId", "==", uid).get();
  const strayVariations = theirVariations.docs.filter((doc) => !ownedRecipeIds.has(doc.ref.parent.parent?.id ?? ""));
  strayVariations.forEach((doc) => storagePrefixes.push(VARIATION_IMAGE_PREFIX(doc.id)));
  await deleteRefs(strayVariations.map((doc) => doc.ref));

  // 3. Menus, shopping lists and feed entries.
  for (const collection of ["mealPlans", "shoppingLists", "activities"]) {
    const snap = await db.collection(collection).where("authorId", "==", uid).get();
    await deleteRefs(snap.docs.map((doc) => doc.ref));
  }

  // 4. Friend requests, sent and received.
  for (const field of ["fromUserId", "toUserId"]) {
    const snap = await db.collection("friendRequests").where(field, "==", uid).get();
    await deleteRefs(snap.docs.map((doc) => doc.ref));
  }

  // 5. Out of every friend's list.
  const friendsOf = await db.collection("users").where("friends", "array-contains", uid).get();
  for (const chunk of chunkArray(friendsOf.docs, BATCH_SIZE)) {
    const batch = db.batch();
    chunk.forEach((doc) => batch.update(doc.ref, { friends: FieldValue.arrayRemove(uid) }));
    await batch.commit();
  }

  // 6. The profile and everything under it (blocked, …).
  await db.recursiveDelete(db.doc(`users/${uid}`));

  // 7. Photos. A missing file or a storage hiccup shouldn't strand the account.
  const bucket = getStorage().bucket();
  await bucket.file(PROFILE_IMAGE(uid)).delete({ ignoreNotFound: true }).catch((err) => {
    console.error(`deleteAccount: couldn't delete profile image for ${uid}`, err);
  });
  for (const prefix of storagePrefixes) {
    await bucket.deleteFiles({ prefix }).catch((err) => {
      console.error(`deleteAccount: couldn't delete ${prefix}* for ${uid}`, err);
    });
  }

  console.log(
    `deleteAccount: cleared ${uid} — ${recipes.size} recipes, ${strayVariations.length} variations elsewhere, ` +
      `${friendsOf.size} friend lists, ${storagePrefixes.length} photo prefixes`
  );
}

/** The last step: the sign-in itself. */
export async function deleteAuthUser(uid: string): Promise<void> {
  try {
    await getAuth().deleteUser(uid);
  } catch (err) {
    // A retry after a run that already got this far: nothing left to remove.
    if ((err as { code?: string }).code === "auth/user-not-found") return;
    throw err;
  }
}

async function deleteRefs(refs: DocumentReference[]): Promise<void> {
  const db = getFirestore();
  for (const chunk of chunkArray(refs, BATCH_SIZE)) {
    const batch = db.batch();
    chunk.forEach((ref) => batch.delete(ref));
    await batch.commit();
  }
}

function chunkArray<T>(arr: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}
