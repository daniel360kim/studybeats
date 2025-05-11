// functions/mailchimpHooks.js

const { onDocumentWritten, onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const mailchimp = require("@mailchimp/mailchimp_marketing"); // The official Mailchimp SDK
const logger = require("firebase-functions/logger");
const { defineString, defineSecret } = require("firebase-functions/params");

// --- Define Firebase Function Parameters ---
// These parameters will be configured for your deployed functions.
// For local emulation, their values will be sourced from .env.local (or other .env files).

// Non-sensitive parameters (can be set via .env files or prompted during deploy)
const mailchimpAudienceIdParam = defineString("MAILCHIMP_AUDIENCE_ID");
const mailchimpServerPrefixParam = defineString("MAILCHIMP_SERVER_PREFIX");

// Sensitive parameter (integrates with Google Cloud Secret Manager for deployed functions)
const mailchimpApiKeyParam = defineSecret("MAILCHIMP_API_KEY");

// Initialize Firebase Admin SDK (idempotent - safe to call multiple times)
try {
  if (admin.apps.length === 0) { // Check if any app has been initialized
    admin.initializeApp();
  }
} catch (e) {
  logger.warn("Firebase Admin SDK already initialized or error during initialization:", e.message);
}
const db = admin.firestore(); // Get a Firestore instance

// --- Default Notification Settings ---
// Define what the default state of all notification preferences should be if a setting is not specified.
const defaultNotificationSettings = {
    marketingEmailsEnabled: true,
    productUpdatesEnabled: true,
    weeklySummaryEnabled: true,
    // Add other notification types and their default true/false values here
};

/**
 * Helper function to get an initialized Mailchimp API client.
 * This should be called *inside* the Cloud Function runtime,
 * as secret parameters are only available then.
 * @returns {object | null} The configured Mailchimp client or null if configuration fails.
 */
function getMailchimpClient() {
    try {
        const apiKey = mailchimpApiKeyParam.value(); // Access secret value at runtime
        const serverPrefix = mailchimpServerPrefixParam.value(); // Access string value at runtime

        if (apiKey && serverPrefix) {
            mailchimp.setConfig({
                apiKey: apiKey,
                server: serverPrefix,
            });
            // logger.info("Mailchimp client configured successfully for this execution.");
            return mailchimp; // Return the configured mailchimp object
        } else {
            logger.error("CRITICAL: Mailchimp API Key or Server Prefix parameter values are missing or unresolved in runtime. Cannot configure Mailchimp client.");
            return null;
        }
    } catch (error) {
        logger.error("CRITICAL: Error accessing Mailchimp parameters (API Key/Server Prefix) in runtime.", error);
        return null;
    }
}

/**
 * Helper function to unsubscribe a user from Mailchimp.
 * @param {object} mcClient - The initialized Mailchimp client.
 * @param {string} mailchimpAudienceId - The Mailchimp Audience ID.
 * @param {string} userEmail - The email of the user to unsubscribe.
 * @param {string} reason - A logging reason for the unsubscription.
 */
async function unsubscribeUserFromMailchimp(mcClient, mailchimpAudienceId, userEmail, reason) {
    if (!userEmail) {
        logger.warn(`Cannot unsubscribe from Mailchimp: email is undefined or null. Reason: ${reason}`);
        return;
    }
    if (!mcClient) {
        logger.error(`Mailchimp client not available for unsubscribing ${userEmail}. Reason: ${reason}`);
        return;
    }
    if (!mailchimpAudienceId) {
        logger.error(`Mailchimp Audience ID not available for unsubscribing ${userEmail}. Reason: ${reason}`);
        return;
    }

    logger.info(`Attempting to unsubscribe ${userEmail} from Mailchimp. Reason: ${reason}`);
    try {
        await mcClient.lists.updateListMember(
            mailchimpAudienceId,
            userEmail,
            { status: "unsubscribed" }
        );
        logger.info(`Successfully unsubscribed ${userEmail} from Mailchimp (or member was already not found/unsubscribed).`);
    } catch (error) {
        if (error.status === 404) { // HTTP 404 Not Found
            logger.info(`User ${userEmail} not found in Mailchimp audience '${mailchimpAudienceId}'. No unsubscription action needed for: ${reason}.`);
        } else {
            const errorBody = error.response?.body ? JSON.stringify(error.response.body) : error.message;
            logger.error(`Error unsubscribing ${userEmail} from Mailchimp (Reason: ${reason}): Status ${error.status}, Body: ${errorBody}`);
        }
    }
}


/**
 * Firestore Trigger: When a new document is created in the 'users' collection.
 * This function creates default notification settings for the new user.
 * The creation of these settings will then trigger `manageMailchimpFromNotificationSettingsChange`.
 */
const initializeUserSettingsOnUserCreateFunction = onDocumentCreated(
    "users/{userEmail}", // Trigger on creation of a user document
    async (event) => {
        const userEmail = event.params.userEmail; // Email is the document ID
        // const userData = event.data.data(); // Data of the newly created user document, if needed

        logger.info(`New user document created for: ${userEmail}. Initializing notification settings.`);

        // Path for the notification settings subcollection document
        const settingsDocRef = db.collection("users").doc(userEmail).collection("notificationSettings").doc("preferences");

        try {
            // Check if settings already exist (e.g., created by another process simultaneously, though unlikely for onCreate)
            const settingsSnap = await settingsDocRef.get();
            if (settingsSnap.exists) {
                logger.info(`Notification settings already exist for ${userEmail}. No action needed by initializeUserSettingsOnUserCreate.`);
                return null;
            }

            // Create the notification settings document with defaults
            // This action will, in turn, trigger the `manageMailchimpFromNotificationSettingsChange` function.
            await settingsDocRef.set(defaultNotificationSettings);
            logger.info(`Created default notification settings for ${userEmail}. Mailchimp sync will be handled by the settings trigger.`);

        } catch (error) {
            logger.error(`Error initializing notification settings for new user ${userEmail}:`, error);
        }
        return null;
    }
);

/**
 * Firestore Trigger: Manages Mailchimp subscriptions based on changes to
 * users/{userEmail}/notificationSettings/preferences.
 * This is the primary function for syncing to Mailchimp based on preferences.
 */
const manageMailchimpFromNotificationSettingsChangeFunction = onDocumentWritten(
    "users/{userEmail}/notificationSettings/preferences",
    async (event) => {
        const userEmail = event.params.userEmail;
        const settingsDocRef = db.doc(`users/${userEmail}/notificationSettings/preferences`);

        const mcClient = getMailchimpClient();
        if (!mcClient) {
            logger.error(`Aborting manageMailchimpFromNotificationSettingsChange for ${userEmail}: Mailchimp client init failed.`);
            return null;
        }
        const mailchimpAudienceId = mailchimpAudienceIdParam.value();
        if (!mailchimpAudienceId) {
            logger.error(`Aborting manageMailchimpFromNotificationSettingsChange for ${userEmail}: Mailchimp Audience ID missing.`);
            return null;
        }

        // Case 1: Notification settings document was DELETED
        if (!event.data.after.exists) {
            await unsubscribeUserFromMailchimp(mcClient, mailchimpAudienceId, userEmail, "Notification settings document deleted");
            return null;
        }

        // Case 2: Notification settings document was CREATED or UPDATED
        let currentSettings = event.data.after.data() || {};
        let needsFirestoreUpdate = false;

        // Apply defaults if fields are missing
        for (const key in defaultNotificationSettings) {
            if (typeof currentSettings[key] === 'undefined') {
                currentSettings[key] = defaultNotificationSettings[key];
                needsFirestoreUpdate = true;
            }
        }

        if (needsFirestoreUpdate) {
            try {
                logger.info(`Updating Firestore notificationSettings for ${userEmail} with defaults (triggered by settings change):`, currentSettings);
                await settingsDocRef.set(currentSettings, { merge: true });
                logger.info(`Successfully updated Firestore with complete settings for ${userEmail} (triggered by settings change).`);
            } catch (firestoreError) {
                logger.error(`Error updating Firestore with default settings for ${userEmail} (triggered by settings change):`, firestoreError);
            }
        }

        const wantsMarketingEmails = currentSettings.marketingEmailsEnabled;
        const mailchimpMemberStatus = wantsMarketingEmails ? "subscribed" : "unsubscribed";
        const memberData = {
            email_address: userEmail,
            status: mailchimpMemberStatus,
        };

        logger.info(`Attempting to set Mailchimp status for ${userEmail} to ${mailchimpMemberStatus} based on notification settings.`);
        try {
            await mcClient.lists.setListMember(mailchimpAudienceId, userEmail, memberData);
            logger.info(`Successfully set Mailchimp status for ${userEmail} to ${mailchimpMemberStatus}.`);
        } catch (error) {
            const errorBody = error.response?.body ? JSON.stringify(error.response.body) : error.message;
            logger.error(`Error setting Mailchimp member status for ${userEmail}: Status ${error.status}, Body: ${errorBody}`);
        }
        return null;
    }
);

/**
 * Firestore Trigger: When a document in users/{userEmail} is deleted.
 * This function unsubscribes the user from Mailchimp and attempts to clean up their
 * notification settings subcollection document.
 */
const cleanupUserOnDeleteFunction = onDocumentDeleted(
    "users/{userEmail}",
    async (event) => {
        const userEmail = event.params.userEmail;
        const deletedUserData = event.data.data(); // Data of the user document that was deleted

        logger.info(`User document users/${userEmail} deleted from Firestore. Name: ${deletedUserData?.displayName || 'N/A'}. Processing Mailchimp unsubscription and settings cleanup.`);

        const mcClient = getMailchimpClient();
        if (!mcClient) {
            logger.error(`Aborting cleanupUserOnDelete for ${userEmail}: Mailchimp client init failed.`);
            return null;
        }
        const mailchimpAudienceId = mailchimpAudienceIdParam.value();
        if (!mailchimpAudienceId) {
            logger.error(`Aborting cleanupUserOnDelete for ${userEmail}: Mailchimp Audience ID missing.`);
            return null;
        }

        // Unsubscribe from Mailchimp
        await unsubscribeUserFromMailchimp(mcClient, mailchimpAudienceId, userEmail, "Firestore user document deleted");

        // Delete the notificationSettings/preferences document for this user
        const settingsDocRef = db.collection("users").doc(userEmail).collection("notificationSettings").doc("preferences");
        try {
            await settingsDocRef.delete();
            logger.info(`Successfully deleted notificationSettings/preferences for deleted user ${userEmail}.`);
        } catch (error) {
            if (error.code === 5) { // Firestore error code 5 is "NOT_FOUND"
                 logger.info(`Notification settings for ${userEmail} not found during cleanup, likely already deleted or never existed.`);
            } else {
                logger.error(`Error deleting notificationSettings/preferences for user ${userEmail} during cleanup:`, error);
            }
        }
        return null;
    }
);

// Export all the functions
module.exports = {
    initializeUserSettingsOnUserCreate: initializeUserSettingsOnUserCreateFunction,
    manageMailchimpFromNotificationSettingsChange: manageMailchimpFromNotificationSettingsChangeFunction,
    cleanupUserOnDelete: cleanupUserOnDeleteFunction,
    // If you have the seedTestUsers function in this file, export it as well:
    // seedTestUsers: seedTestUsersFunction, // (Assuming seedTestUsersFunction is defined elsewhere or you add it here)
};
