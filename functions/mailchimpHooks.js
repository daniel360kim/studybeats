// functions/mailchimpHooks.js

const { onDocumentWritten, onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https"); // For HTTP functions
const admin = require("firebase-admin");
const mailchimp = require("@mailchimp/mailchimp_marketing");
const logger = require("firebase-functions/logger");
const { defineString, defineSecret } = require("firebase-functions/params");

// --- Define Firebase Function Parameters ---
const mailchimpAudienceIdParam = defineString("MAILCHIMP_AUDIENCE_ID");
const mailchimpServerPrefixParam = defineString("MAILCHIMP_SERVER_PREFIX");
const mailchimpApiKeyParam = defineSecret("MAILCHIMP_API_KEY");
const backfillSecretKeyParam = defineSecret("BACKFILL_SECRET_KEY_SM");


// Initialize Firebase Admin SDK
try {
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
} catch (e) {
  logger.warn("Firebase Admin SDK already initialized or error during initialization:", e.message);
}
const db = admin.firestore();

// --- Default Notification Settings ---
const defaultNotificationSettings = {
    marketingEmailsEnabled: true,
    productUpdatesEnabled: true,
    todoNotificationsEnabled: true,
};

// --- Tag Names ---
const TAG_MARKETING_EMAILS = "Marketing Emails";
const TAG_PRODUCT_UPDATES = "Product Updates";
const TAG_TODO_NOTIFICATIONS = "Todo Notifications";

// --- Retry Logic Configuration ---
const MAX_RETRIES = 3; // Max number of retries for Mailchimp API calls
const INITIAL_BACKOFF_MS = 1000; // Initial wait time in milliseconds (1 second)

/**
 * Helper function to introduce a delay.
 * @param {number} ms - Milliseconds to wait.
 * @returns {Promise<void>}
 */
function delay(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Helper function to execute an async Mailchimp API call with retry logic.
 * @param {Function} apiCallFunction - An async function that performs the Mailchimp API call.
 * @param {string} actionDescription - A description of the action for logging.
 * @param {string} userEmail - The user email for logging context.
 * @returns {Promise<any>} The result of the API call if successful.
 * @throws Will re-throw the error if all retries fail or if it's a non-retryable error.
 */
async function executeMailchimpApiWithRetry(apiCallFunction, actionDescription, userEmail) {
    let attempts = 0;
    let currentBackoff = INITIAL_BACKOFF_MS;

    while (attempts < MAX_RETRIES) {
        attempts++;
        try {
            logger.info(`Attempt ${attempts} for Mailchimp action "${actionDescription}" for user ${userEmail}.`);
            return await apiCallFunction(); // Attempt the API call
        } catch (error) {
            const status = error.status; // HTTP status code from Mailchimp error
            const isRetryable = (status === 429) || (status >= 500 && status <= 599);

            logger.warn(`Mailchimp action "${actionDescription}" for user ${userEmail} failed on attempt ${attempts} with status ${status}. Error: ${error.message}`, {
                errorDetails: error.response?.body || error,
            });

            if (isRetryable && attempts < MAX_RETRIES) {
                logger.info(`Retrying Mailchimp action "${actionDescription}" for ${userEmail} in ${currentBackoff}ms...`);
                await delay(currentBackoff);
                currentBackoff *= 2; // Exponential backoff
            } else {
                logger.error(`Mailchimp action "${actionDescription}" for ${userEmail} failed after ${attempts} attempts or with non-retryable error. Status: ${status}.`);
                throw error; // Re-throw the error if max retries reached or error is not retryable
            }
        }
    }
}


/**
 * Helper function to get an initialized Mailchimp API client.
 */
function getMailchimpClient() {
    try {
        const apiKey = mailchimpApiKeyParam.value();
        const serverPrefix = mailchimpServerPrefixParam.value();

        if (process.env.FUNCTIONS_EMULATOR === 'true') {
            logger.info("DEBUG: Mailchimp Parameters (Emulator):", {
                serverPrefix: serverPrefix,
                apiKeyIsPresent: !!apiKey,
                apiKeyFirstChars: apiKey ? apiKey.substring(0, 4) + "..." : "NOT_SET",
            });
        }

        if (apiKey && serverPrefix) {
            mailchimp.setConfig({ apiKey: apiKey, server: serverPrefix });
            return mailchimp;
        } else {
            logger.error("CRITICAL: Mailchimp API Key or Server Prefix parameter values are missing. Cannot configure Mailchimp client.");
            return null;
        }
    } catch (error) {
        logger.error("CRITICAL: Error accessing Mailchimp parameters (API Key/Server Prefix) in runtime.", error);
        return null;
    }
}

/**
 * Helper function to update a user's status and tags in Mailchimp.
 */
async function syncUserToMailchimpWithTags(mcClient, mailchimpAudienceId, userEmail, settings, previousSettings = null) {
    if (!mcClient || !mailchimpAudienceId || !userEmail) {
        logger.error("Missing critical info for Mailchimp sync.", { userEmail, hasClient: !!mcClient, hasAudienceId: !!mailchimpAudienceId });
        return;
    }

    const isGenerallySubscribed = settings.marketingEmailsEnabled ||
                                  settings.productUpdatesEnabled ||
                                  settings.todoNotificationsEnabled;
    const overallStatus = isGenerallySubscribed ? "subscribed" : "unsubscribed";

    const activeTagNames = [];
    if (settings.marketingEmailsEnabled) activeTagNames.push(TAG_MARKETING_EMAILS);
    if (settings.productUpdatesEnabled) activeTagNames.push(TAG_PRODUCT_UPDATES);
    if (settings.todoNotificationsEnabled) activeTagNames.push(TAG_TODO_NOTIFICATIONS);

    const memberDataForSet = {
        email_address: userEmail,
        status: overallStatus,
        tags: activeTagNames,
    };

    logger.info(`Attempting to set Mailchimp status for ${userEmail} to ${overallStatus} with active tags:`, activeTagNames);
    try {
        await executeMailchimpApiWithRetry(
            async () => mcClient.lists.setListMember(mailchimpAudienceId, userEmail, memberDataForSet),
            "setListMember (status & active tags)",
            userEmail
        );
        logger.info(`Successfully set Mailchimp status and active tags for ${userEmail}.`);

        const tagsToManageStatus = [];
        if (previousSettings) {
            if (previousSettings.marketingEmailsEnabled && !settings.marketingEmailsEnabled) {
                tagsToManageStatus.push({ name: TAG_MARKETING_EMAILS, status: "inactive" });
            }
            if (previousSettings.productUpdatesEnabled && !settings.productUpdatesEnabled) {
                tagsToManageStatus.push({ name: TAG_PRODUCT_UPDATES, status: "inactive" });
            }
            if (previousSettings.todoNotificationsEnabled && !settings.todoNotificationsEnabled) {
                tagsToManageStatus.push({ name: TAG_TODO_NOTIFICATIONS, status: "inactive" });
            }
        } else if (!isGenerallySubscribed) {
            if (!settings.marketingEmailsEnabled) tagsToManageStatus.push({ name: TAG_MARKETING_EMAILS, status: "inactive" });
            if (!settings.productUpdatesEnabled) tagsToManageStatus.push({ name: TAG_PRODUCT_UPDATES, status: "inactive" });
            if (!settings.todoNotificationsEnabled) tagsToManageStatus.push({ name: TAG_TODO_NOTIFICATIONS, status: "inactive" });
        }
        // Ensure active tags are explicitly set to active if they changed from inactive
        if (settings.marketingEmailsEnabled && (!previousSettings || !previousSettings.marketingEmailsEnabled)) {
             tagsToManageStatus.push({ name: TAG_MARKETING_EMAILS, status: "active" });
        }
        if (settings.productUpdatesEnabled && (!previousSettings || !previousSettings.productUpdatesEnabled)) {
             tagsToManageStatus.push({ name: TAG_PRODUCT_UPDATES, status: "active" });
        }
        if (settings.todoNotificationsEnabled && (!previousSettings || !previousSettings.todoNotificationsEnabled)) {
             tagsToManageStatus.push({ name: TAG_TODO_NOTIFICATIONS, status: "active" });
        }

        const uniqueTagsToManage = tagsToManageStatus.filter((tag, index, self) =>
            index === self.findIndex((t) => t.name === tag.name && t.status === tag.status)
        );

        if (uniqueTagsToManage.length > 0) {
            logger.info(`Attempting to update specific tag statuses for ${userEmail}:`, uniqueTagsToManage);
            await executeMailchimpApiWithRetry(
                async () => mcClient.lists.updateListMemberTags(mailchimpAudienceId, userEmail, { tags: uniqueTagsToManage }),
                "updateListMemberTags (specific tag statuses)",
                userEmail
            );
            logger.info(`Successfully sent specific tag status updates for ${userEmail}.`);
        }
    } catch (error) {
        // Error already logged by executeMailchimpApiWithRetry if all retries failed
        // We log a final summary error here.
        const errorBody = error.response?.body ? JSON.stringify(error.response.body) : error.message;
        logger.error(`Failed to fully sync Mailchimp member status/tags for ${userEmail} after retries: Status ${error.status}, Body: ${errorBody}`);
    }
}

/**
 * Firestore Trigger: When a new document is created in the 'users' collection.
 */
const initializeUserSettingsOnUserCreateFunction = onDocumentCreated(
    "users/{userEmail}",
    async (event) => {
        const userEmail = event.params.userEmail;
        logger.info(`New user document created for: ${userEmail}. Initializing notification settings.`);
        const settingsDocRef = db.collection("users").doc(userEmail).collection("notificationSettings").doc("preferences");
        try {
            const settingsSnap = await settingsDocRef.get();
            if (settingsSnap.exists) {
                logger.info(`Notification settings already exist for ${userEmail}. Will not overwrite.`);
                return null;
            }
            await settingsDocRef.set(defaultNotificationSettings);
            logger.info(`Created default notification settings for ${userEmail}. Mailchimp sync will be handled by the settings trigger.`);
        } catch (error) {
            logger.error(`Error initializing notification settings for new user ${userEmail}:`, error);
        }
        return null;
    }
);

/**
 * Firestore Trigger: Manages Mailchimp subscriptions and tags based on changes to
 * users/{userEmail}/notificationSettings/preferences.
 */
const manageMailchimpFromNotificationSettingsChangeFunction = onDocumentWritten(
    "users/{userEmail}/notificationSettings/preferences",
    async (event) => {
        const userEmail = event.params.userEmail;
        const settingsDocRef = db.doc(`users/${userEmail}/notificationSettings/preferences`);

        const mcClient = getMailchimpClient();
        if (!mcClient) {
            logger.error(`Aborting for ${userEmail}: Mailchimp client init failed.`);
            return null;
        }
        const mailchimpAudienceId = mailchimpAudienceIdParam.value();
        if (!mailchimpAudienceId) {
            logger.error(`Aborting for ${userEmail}: Mailchimp Audience ID missing.`);
            return null;
        }

        const previousSettings = event.data.before.exists ? event.data.before.data() : null;

        if (!event.data.after.exists) {
            logger.info(`Notification settings for ${userEmail} deleted. Setting all relevant tags to inactive and unsubscribing from Mailchimp.`);
            const allFalseSettings = {};
            for (const key in defaultNotificationSettings) {
                allFalseSettings[key] = false;
            }
            await syncUserToMailchimpWithTags(mcClient, mailchimpAudienceId, userEmail, allFalseSettings, previousSettings);
            return null;
        }

        let currentSettings = event.data.after.data() || {};
        let needsFirestoreUpdate = false;

        for (const key in defaultNotificationSettings) {
            if (typeof currentSettings[key] === 'undefined') {
                currentSettings[key] = defaultNotificationSettings[key];
                needsFirestoreUpdate = true;
            }
        }

        if (needsFirestoreUpdate) {
            try {
                logger.info(`Updating Firestore notificationSettings for ${userEmail} with defaults:`, currentSettings);
                await settingsDocRef.set(currentSettings, { merge: true });
                logger.info(`Successfully updated Firestore with complete settings for ${userEmail}.`);
            } catch (firestoreError) {
                logger.error(`Error updating Firestore with default settings for ${userEmail}:`, firestoreError);
            }
        }
        await syncUserToMailchimpWithTags(mcClient, mailchimpAudienceId, userEmail, currentSettings, previousSettings);
        return null;
    }
);

/**
 * Firestore Trigger: When a document in users/{userEmail} is deleted.
 */
const cleanupUserOnDeleteFunction = onDocumentDeleted(
    "users/{userEmail}",
    async (event) => {
        const userEmail = event.params.userEmail;
        logger.info(`User document users/${userEmail} deleted from Firestore. Processing Mailchimp unsubscription and settings cleanup.`);

        const mcClient = getMailchimpClient();
        if (!mcClient) {
            logger.error(`Aborting cleanup for ${userEmail}: Mailchimp client init failed.`);
            return null;
        }
        const mailchimpAudienceId = mailchimpAudienceIdParam.value();
        if (!mailchimpAudienceId) {
            logger.error(`Aborting cleanup for ${userEmail}: Mailchimp Audience ID missing.`);
            return null;
        }

        const allFalseSettings = {};
        for (const key in defaultNotificationSettings) {
            allFalseSettings[key] = false;
        }
        await syncUserToMailchimpWithTags(mcClient, mailchimpAudienceId, userEmail, allFalseSettings, null);

        const settingsDocRef = db.collection("users").doc(userEmail).collection("notificationSettings").doc("preferences");
        try {
            await settingsDocRef.delete();
            logger.info(`Successfully deleted notificationSettings/preferences for deleted user ${userEmail}.`);
        } catch (error) {
            if (error.code === 5) {
                 logger.info(`Notification settings for ${userEmail} not found during cleanup.`);
            } else {
                logger.error(`Error deleting notificationSettings for ${userEmail} during cleanup:`, error);
            }
        }
        return null;
    }
);

/**
 * HTTP Trigger: Iterates through all users and creates default notification settings
 * for those who don't have them. This will subsequently trigger Mailchimp sync.
 */
const backfillDefaultNotificationSettingsFunction = onRequest(
    {
        timeoutSeconds: 540,
        region: "us-central1",
        secrets: ["BACKFILL_SECRET_KEY_SM"],
    },
    async (request, response) => {
        const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
        logger.info(`backfillDefaultNotificationSettingsFunction triggered. Emulator mode: ${isEmulator}`);

        let actualBackfillSecretKeyValue;
        if (isEmulator) {
            actualBackfillSecretKeyValue = process.env.BACKFILL_SECRET_KEY_SM;
        } else {
            try {
                actualBackfillSecretKeyValue = backfillSecretKeyParam.value();
            } catch (e) {
                logger.error("Failed to retrieve BACKFILL_SECRET_KEY_SM from Secret Manager:", e);
                response.status(500).send("Server configuration error for backfill secret.");
                return;
            }
        }

        if (request.query.secret !== actualBackfillSecretKeyValue) {
             logger.warn("Unauthorized attempt to run backfillDefaultNotificationSettings. Aborting.", {
                isEmulator: isEmulator,
                providedSecret: request.query.secret,
             });
             response.status(403).send("Unauthorized: This function is protected. Provide the correct 'secret' query parameter.");
             return;
        }
        if (!actualBackfillSecretKeyValue) {
            logger.error("CRITICAL: BACKFILL_SECRET_KEY_SM is not configured for the environment. Aborting.");
            response.status(500).send("Server configuration error: Backfill secret not available.");
            return;
        }

        logger.info("Authorization successful for backfill. Proceeding...");
        let usersProcessed = 0;
        let settingsCreatedCount = 0;
        const batchSize = 200;
        let currentBatch = db.batch();
        let operationsInCurrentBatch = 0;

        try {
            const usersSnapshot = await db.collection("users").get();
            if (usersSnapshot.empty) {
                logger.info("No users found in the 'users' collection for backfill.");
                response.status(200).send("No users found to process.");
                return;
            }

            logger.info(`Found ${usersSnapshot.size} total users for backfill. Checking for missing notification settings...`);

            for (const userDoc of usersSnapshot.docs) {
                usersProcessed++;
                const userEmail = userDoc.id;
                const settingsDocRef = userDoc.ref.collection("notificationSettings").doc("preferences");

                try {
                    const settingsSnap = await settingsDocRef.get();
                    if (!settingsSnap.exists) {
                        logger.info(`User ${userEmail} is missing notification settings during backfill. Adding to batch to create defaults.`);
                        currentBatch.set(settingsDocRef, defaultNotificationSettings);
                        operationsInCurrentBatch++;
                        settingsCreatedCount++;

                        if (operationsInCurrentBatch >= batchSize) {
                            logger.info(`Committing batch of ${operationsInCurrentBatch} settings creations during backfill...`);
                            await currentBatch.commit();
                            currentBatch = db.batch();
                            operationsInCurrentBatch = 0;
                            logger.info("Backfill batch committed. Continuing...");
                        }
                    }
                } catch (userProcessingError) {
                    logger.error(`Error processing user ${userEmail} during backfill check/batching:`, userProcessingError);
                }
            }

            if (operationsInCurrentBatch > 0) {
                logger.info(`Committing final batch of ${operationsInCurrentBatch} settings creations during backfill...`);
                await currentBatch.commit();
                logger.info("Final backfill batch committed.");
            }

            const message = `Backfill completed. Processed ${usersProcessed} users. Created default notification settings for ${settingsCreatedCount} users. Each creation will trigger Mailchimp sync.`;
            logger.info(message);
            response.status(200).send(message);

        } catch (error) {
            logger.error("Error during backfillDefaultNotificationSettingsFunction execution:", error);
            response.status(500).send("An error occurred during backfill. Check Cloud Function logs.");
        }
    }
);

// Export all the functions
module.exports = {
    initializeUserSettingsOnUserCreate: initializeUserSettingsOnUserCreateFunction,
    manageMailchimpFromNotificationSettingsChange: manageMailchimpFromNotificationSettingsChangeFunction,
    cleanupUserOnDelete: cleanupUserOnDeleteFunction,
    backfillDefaultNotificationSettings: backfillDefaultNotificationSettingsFunction,
};
