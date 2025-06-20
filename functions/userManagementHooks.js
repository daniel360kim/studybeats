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
      // Recursively delete the user document and all its subcollections
      await firestore.recursiveDelete(doc.ref);
      logger.info(`Successfully recursively deleted Firestore document and subcollections at users/${doc.id} for Auth user UID ${userId}.`);

      // Example: delete user-specific collection outside of 'users', e.g. 'userData/{uid}'
      const externalUserDoc = firestore.collection('userData').doc(userId);
      const externalDocSnapshot = await externalUserDoc.get();
      if (externalDocSnapshot.exists) {
        await firestore.recursiveDelete(externalUserDoc);
        logger.info(`Also deleted external userData/${userId} recursively.`);
      }
    });

    await Promise.all(deletePromises);
  } catch (error) {
    logger.error(`Error recursively deleting Firestore user document for Auth user UID ${userId}:`, error);
  }

  return null;
});


const cleanupOldAnonymousUsers = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  const thresholdDays = 7;
  const cutoffDate = Date.now() - thresholdDays * 24 * 60 * 60 * 1000;

  try {
    const listUsersResult = await admin.auth().listUsers();
    const deletionPromises = [];

    for (const userRecord of listUsersResult.users) {
      const user = userRecord.toJSON();
      const isAnonymous = user.providerData.length === 0;

      if (isAnonymous) {
        const userDocSnapshot = await db.collection('users').where('uid', '==', user.uid).get();

        for (const doc of userDocSnapshot.docs) {
          const lastUsed = doc.get('lastUsed');
          const lastUsedTimestamp = lastUsed?.toMillis?.() || 0;

          if (lastUsedTimestamp < cutoffDate) {
            logger.info(`Deleting anonymous user UID ${user.uid} with lastUsed: ${new Date(lastUsedTimestamp).toISOString()}`);

            deletionPromises.push(db.recursiveDelete(doc.ref));
            deletionPromises.push(admin.auth().deleteUser(user.uid));
          }
        }
      }
    }

    await Promise.all(deletionPromises);
    logger.info(`Old anonymous users cleanup completed.`);
  } catch (error) {
    logger.error('Error during cleanup of old anonymous users:', error);
  }

  return null;
});

const handleAuthUserCreation = functions.auth.user().onCreate(async (user) => {
  const firestore = getFirestore();
  const usageDocRef = firestore.collection('analytics').doc('usage');

  const isAnonymous = user.providerData.length === 0;

  try {
    await firestore.runTransaction(async (transaction) => {
      const usageDoc = await transaction.get(usageDocRef);
      const data = usageDoc.exists ? usageDoc.data() : {};

      transaction.set(usageDocRef, {
        totalAnonymousUsers: (data.totalAnonymousUsers || 0) + (isAnonymous ? 1 : 0),
        totalRegisteredUsers: (data.totalRegisteredUsers || 0) + (!isAnonymous ? 1 : 0)
      }, { merge: true });
    });

    logger.info(`Incremented ${isAnonymous ? 'anonymous' : 'registered'} user count for UID ${user.uid}`);
  } catch (error) {
    logger.error(`Error incrementing usage statistics for UID ${user.uid}:`, error);
  }

  return null;
});



// Export the functions to be used in index.js
module.exports = {
    handleAuthUserDeletionV1: handleAuthUserDeletionV1Function,
    cleanupOldAnonymousUsers: cleanupOldAnonymousUsers,
    handleAuthUserCreation: handleAuthUserCreation,
};


