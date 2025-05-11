// functions/index.js

const admin = require("firebase-admin");

// Initialize Firebase Admin SDK.
try {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
} catch (e) {
  console.warn("Firebase Admin SDK already initialized or error during initialization in index.js:", e.message);
}

// Import functions from mailchimpHooks.js
const mailchimpRelatedFunctions = require('./mailchimpHooks');
// Import functions from userManagementHooks.js
const userManagementRelatedFunctions = require('./userManagementHooks');


// --- Re-export functions from mailchimpHooks.js ---
exports.initializeUserSettingsOnUserCreate = mailchimpRelatedFunctions.initializeUserSettingsOnUserCreate;
exports.manageMailchimpFromNotificationSettingsChange = mailchimpRelatedFunctions.manageMailchimpFromNotificationSettingsChange;
exports.cleanupUserOnDelete = mailchimpRelatedFunctions.cleanupUserOnDelete; // This is the Firestore onDocumentDeleted trigger
exports.backfillDefaultNotificationSettings = mailchimpRelatedFunctions.backfillDefaultNotificationSettings;

// --- Re-export functions from userManagementHooks.js ---
exports.handleAuthUserDeletionV1 = userManagementRelatedFunctions.handleAuthUserDeletionV1; // This is the Auth onUserDeleted trigger


// Example of another function directly in index.js (if you have any)
// const { onRequest } = require("firebase-functions/v2/https");
// const logger = require("firebase-functions/logger");
//
// exports.simpleHttpTest = onRequest((request, response) => {
//   logger.info("Simple HTTP Test function called from index.js!");
//   response.send("Hello from a simple function in index.js!");
// });

// Ensure all functions you intend to deploy are exported from this file.
