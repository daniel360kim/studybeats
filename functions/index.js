// --- Corrected Imports ---
const functions = require("firebase-functions"); 
const admin = require("firebase-admin");
const { onCall } = require("firebase-functions/v2/https");

// Imports needed for the PDF conversion logic
const PDFDocument = require("pdfkit"); // Use pdfkit for server-side PDF generation
const { Writable } = require("stream");


// --- Firebase Initialization ---
try {
  // Initialize Firebase Admin SDK only once
  if (admin.apps.length === 0) {
    admin.initializeApp();
  }
} catch (e) {
  console.warn("Firebase Admin SDK already initialized or error in index.js:", e.message);
}

// --- Import all function logic files ---
const mailchimpRelatedFunctions = require('./mailchimpHooks');
const userManagementRelatedFunctions = require('./userManagementHooks');
const weatherFunctions = require('./weather');
const pdfGeneratorFunctions = require('./pdfGenerator');

// --- Runtime Options for memory-intensive functions ---
const runtimeOpts = {
  timeoutSeconds: 300, // 5 minutes
  memory: "1GiB",      // 1 GB of memory
};

// --- Export all functions ---

// Mailchimp
exports.initializeUserSettingsOnUserCreate = mailchimpRelatedFunctions.initializeUserSettingsOnUserCreate;
exports.manageMailchimpFromNotificationSettingsChange = mailchimpRelatedFunctions.manageMailchimpFromNotificationSettingsChange;
exports.cleanupUserOnDelete = mailchimpRelatedFunctions.cleanupUserOnDelete;
exports.backfillDefaultNotificationSettings = mailchimpRelatedFunctions.backfillDefaultNotificationSettings;

// User Management
exports.handleAuthUserDeletionV1 = userManagementRelatedFunctions.handleAuthUserDeletionV1;
exports.cleanupOldAnonymousUsers = userManagementRelatedFunctions.cleanupOldAnonymousUsers; 
exports.handleAuthUserCreation = userManagementRelatedFunctions.handleAuthUserCreation;

// Weather
exports.getWeather = weatherFunctions.getWeather;
