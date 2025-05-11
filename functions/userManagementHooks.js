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
    // For v1, the 'user' object is the UserRecord directly
    const userEmail = user.email;
    const userId = user.uid;

    if (!userEmail) {
        logger.warn(`User with UID ${userId} was deleted from Auth, but no email was found. Cannot delete Firestore user document by email.`);
        return null;
    }

    logger.info(`Firebase Auth user ${userEmail} (UID: ${userId}) was deleted (v1 trigger). Attempting to delete corresponding Firestore document at users/${userId}.`);

    try {
      const path = `users/${userEmail}`;
      const firestore = getFirestore();
      await firestore.recursiveDelete(firestore.doc(path));
      logger.info(`Successfully recursively deleted Firestore document and subcollections at ${path} for Auth user UID ${userId} (v1 trigger).`);
    } catch (error) {
      logger.error(`Error recursively deleting Firestore document for Auth user UID ${userId} (v1 trigger):`, error);
    }
    return null;
});


// Export the functions to be used in index.js
module.exports = {
    handleAuthUserDeletionV1: handleAuthUserDeletionV1Function,
};
