// functions/userManagementHooks.js

const functions = require("firebase-functions/v1"); // Use the main 'firebase-functions' for v1
const admin = require("firebase-admin");
const { getFirestore } = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

// Ensure Firebase Admin SDK is initialized (idempotent)
try {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
} catch (e) {
  logger.warn("Firebase Admin SDK already initialized or error during initialization in userManagementHooks.js:", e.message);
}
const db = admin.firestore();

/**
 * Auth Trigger (v1 SDK): When a Firebase Authentication user is deleted.
 * This function deletes the corresponding user document from the 'users' collection in Firestore.
 * The deletion of the 'users/{userEmail}' document will then trigger the
 * 'cleanupUserOnDeleteFunction' (defined in mailchimpHooks.js and triggered by Firestore).
 */
const handleAuthUserDeletionV1Function = functions.auth.user().onDelete(async (user) => {
  const userId = user.uid;

  logger.info(`Firebase Auth user (UID: ${userId}) was deleted (v1 trigger). Attempting to locate and delete Firestore document in 'users' collection where uid == ${userId}.`);

  try {
    const firestore = getFirestore();
    const usersQuerySnapshot = await firestore
      .collection('users')
      .where('uid', '==', userId)
      .get();

    if (usersQuerySnapshot.empty) {
      logger.warn(`No Firestore user document found with uid == ${userId}.`);
      return null;
    }

    const deletePromises = usersQuerySnapshot.docs.map(async (doc) => {
      await firestore.recursiveDelete(doc.ref);
      logger.info(`Successfully recursively deleted Firestore document and subcollections at users/${doc.id} for Auth user UID ${userId}.`);
    });

    await Promise.all(deletePromises);
  } catch (error) {
    logger.error(`Error recursively deleting Firestore user document for Auth user UID ${userId}:`, error);
  }

  return null;
});


// Export the functions to be used in index.js
module.exports = {
    handleAuthUserDeletionV1: handleAuthUserDeletionV1Function,
};
