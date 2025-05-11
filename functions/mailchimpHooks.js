// functions/mailchimpHooks.js

const { onDocumentWritten, onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { onRequest } = require("firebase-functions/v2/https"); // For HTTP functions
const admin = require("firebase-admin");
const mailchimp = require("@mailchimp/mailchimp_marketing");
const logger = require("firebase-functions/logger");
const {defineSecret, defineString} = require("firebase-functions/params");

// --- Define Firebase Function Parameters ---
const mailchimpAudienceIdParam = defineString("MAILCHIMP_AUDIENCE_ID");
const mailchimpServerPrefixParam = defineString("MAILCHIMP_SERVER_PREFIX");
const mailchimpApiKeyParam = defineSecret("MAILCHIMP_API_KEY"); // This is sensitive
const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";

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

/**
 * Helper function to get an initialized Mailchimp API client.
 */
async function getMailchimpClient() {
    try {
        const apiKey = isEmulator
            ? process.env.MAILCHIMP_API_KEY // fallback for local development
            :  mailchimpApiKeyParam.value(); // secure access for deployed env
        
        if (apiKey.length == 0) {
            throw new Error("API key is empty.");
        }

        const serverPrefix = isEmulator ? process.env.MAILCHIMP_SERVER_PREFIX :  mailchimpServerPrefixParam.value();
        const audienceId = isEmulator ? process.env.MAILCHIMP_AUDIENCE_ID : mailchimpAudienceIdParam.value();

        logger.info("Mailchimp Parameters Loaded:", {
            audienceId: audienceId,
            serverPrefix: serverPrefix,
            apiKeyIsPresent: !!apiKey,
            apiKeyFirstChars: apiKey ? apiKey.substring(0, 4) + "..." : "NOT_SET",
        });

        if (apiKey && serverPrefix) {
            mailchimp.setConfig({ apiKey: apiKey, server: serverPrefix });
            return mailchimp;
        } else {
            logger.error("Missing API key or server prefix.");
            return null;
        }
    } catch (error) {
        logger.error("Error retrieving Mailchimp parameters:", error);
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

    const memberData = {
        email_address: userEmail,
        status: overallStatus,
        tags: activeTagNames,
    };

    logger.info(`Attempting to set Mailchimp status for ${userEmail} to ${overallStatus} with active tags:`, activeTagNames);
    try {
        await mcClient.lists.setListMember(mailchimpAudienceId, userEmail, memberData);
        logger.info(`Successfully set Mailchimp status and active tags for ${userEmail}.`);

        const tagsToDeactivate = [];
        if (previousSettings) {
            if (previousSettings.marketingEmailsEnabled && !settings.marketingEmailsEnabled) {
                tagsToDeactivate.push({ name: TAG_MARKETING_EMAILS, status: "inactive" });
            }
            if (previousSettings.productUpdatesEnabled && !settings.productUpdatesEnabled) {
                tagsToDeactivate.push({ name: TAG_PRODUCT_UPDATES, status: "inactive" });
            }
            if (previousSettings.todoNotificationsEnabled && !settings.todoNotificationsEnabled) {
                tagsToDeactivate.push({ name: TAG_TODO_NOTIFICATIONS, status: "inactive" });
            }
        } else if (!isGenerallySubscribed) {
            if (!settings.marketingEmailsEnabled) tagsToDeactivate.push({ name: TAG_MARKETING_EMAILS, status: "inactive" });
            if (!settings.productUpdatesEnabled) tagsToDeactivate.push({ name: TAG_PRODUCT_UPDATES, status: "inactive" });
            if (!settings.todoNotificationsEnabled) tagsToDeactivate.push({ name: TAG_TODO_NOTIFICATIONS, status: "inactive" });
        }

        if (tagsToDeactivate.length > 0) {
            logger.info(`Attempting to deactivate tags for ${userEmail}:`, tagsToDeactivate.map(t => t.name));
            await mcClient.lists.updateListMemberTags(mailchimpAudienceId, userEmail, { tags: tagsToDeactivate });
            logger.info(`Successfully sent deactivation for tags for ${userEmail}.`);
        }
    } catch (error) {
        const errorBody = error.response?.body ? JSON.stringify(error.response.body) : error.message;
        logger.error(`Error setting Mailchimp member status/tags for ${userEmail}: Status ${error.status}, Body: ${errorBody}`);
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
                logger.info(`Notification settings already exist for ${userEmail}.`);
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

        const mcClient = await getMailchimpClient(); // This will log params
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

        const mcClient = await getMailchimpClient(); // This will log params
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
    { timeoutSeconds: 540, region: "us-central1" },
    async (request, response) => {
        const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
        // --- LOGGING PARAMETERS FOR HTTP FUNCTION (if needed, getMailchimpClient will also log) ---
        // const mcClientForHttp = getMailchimpClient(); // This would log them
        // if (!mcClientForHttp) {
        //     response.status(500).send("Mailchimp client configuration error.");
        //     return;
        // }
        // const audienceIdForHttp = mailchimpAudienceIdParam.value();
        // logger.info("Backfill HTTP function: Params loaded", { audienceId: audienceIdForHttp });
        // --- END LOGGING FOR HTTP FUNCTION ---


        logger.info(`backfillDefaultNotificationSettingsFunction triggered. Emulator mode: ${isEmulator}`);
        if (!isEmulator && request.query.secret !== BACKFILL_SECRET_KEY) {
             logger.warn("Unauthorized attempt to run backfillDefaultNotificationSettings. Aborting.", {
                isEmulator: isEmulator,
                providedSecret: request.query.secret,
             });
             response.status(403).send("Unauthorized: This function is protected.");
             return;
        }

        logger.info("Authorization successful for backfill. Proceeding...");
        let usersProcessed = 0;
        let settingsCreated = 0;
        const batchSize = 200;
        let batch = db.batch();
        let operationsInBatch = 0;

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
                        logger.info(`User ${userEmail} is missing notification settings during backfill. Preparing to create defaults.`);
                        batch.set(settingsDocRef, defaultNotificationSettings);
                        operationsInBatch++;
                        settingsCreated++;

                        if (operationsInBatch >= batchSize) {
                            logger.info(`Committing batch of ${operationsInBatch} settings creations during backfill...`);
                            await batch.commit();
                            batch = db.batch();
                            operationsInBatch = 0;
                            logger.info("Backfill batch committed. Continuing...");
                        }
                    }
                } catch (userError) {
                    logger.error(`Error processing user ${userEmail} during backfill:`, userError);
                }
            }

            if (operationsInBatch > 0) {
                logger.info(`Committing final batch of ${operationsInBatch} settings creations during backfill...`);
                await batch.commit();
                logger.info("Final backfill batch committed.");
            }

            const message = `Backfill completed. Processed ${usersProcessed} users. Created/initialized default notification settings for ${settingsCreated} users. These creations will trigger Mailchimp sync.`;
            logger.info(message);
            response.status(200).send(message);

        } catch (error) {
            logger.error("Error during backfillDefaultNotificationSettingsFunction:", error);
            response.status(500).send("An error occurred during backfill. Check logs.");
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
