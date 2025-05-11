# Guide: Testing Marketing Emails to Fake Users in Firebase Emulator

This guide will walk you through:
1.  Setting up fake user data in your emulated Firestore.
2.  Creating a Cloud Function to "send" marketing emails to these users based on a notification preference.
3.  Testing and verifying the email "sending" process by inspecting logs within the Firebase Emulator UI.

**Assumptions:**
* You have the Firebase Emulator Suite set up and working (including Firestore and Functions emulators).
* You have a Firebase project with Cloud Functions initialized (e.g., a `functions/index.js` file).
* Your user data will be stored in a Firestore collection named `users`.
* **Each document ID in the `users` collection will be the fake email address itself.**
* Each user document will have a boolean field (e.g., `marketingNotificationsEnabled`) to control if they receive these emails.

---

## Step 1: Prepare Your Cloud Functions Environment

1.  **Navigate to your `functions` directory** in your terminal:
    ```bash
    cd functions
    ```
2.  **Ensure `firebase-admin` and `firebase-functions` are installed:**
    If you haven't already, or to ensure you have them, run:
    ```bash
    npm install firebase-admin firebase-functions
    ```
3.  **Open `functions/index.js` (or your main functions file) in your code editor.**

---

## Step 2: Create Fake User Data in Emulated Firestore

You'll manually add some sample user documents to your *emulated* Firestore.

1.  **Start the Firebase Emulators:**
    In your project root directory, run:
    ```bash
    firebase emulators:start
    ```
2.  **Open the Emulator UI** in your browser (usually `http://127.0.0.1:4000` or the port shown in your terminal, e.g., `http://127.0.0.1:5002/` from your previous logs).

3.  **Go to the Firestore Emulator Tab:**
    * In the Emulator UI, click on "Firestore".

4.  **Add Documents to the `users` Collection:**
    * Click "Start collection".
    * Collection ID: `users`
    * Click "Next".

    * **User 1 (Wants Notifications):**
        * Document ID: `testuser1@example.com` (This is the fake email)
        * Add field:
            * Name: `displayName`
            * Type: `string`
            * Value: `Test User One`
        * Add field:
            * Name: `marketingNotificationsEnabled`
            * Type: `boolean`
            * Value: `true`
        * Click "Save".

    * **User 2 (Does NOT Want Notifications):**
        * Click "Add document" (within the `users` collection).
        * Document ID: `testuser2@example.com`
        * Add field:
            * Name: `displayName`
            * Type: `string`
            * Value: `Test User Two`
        * Add field:
            * Name: `marketingNotificationsEnabled`
            * Type: `boolean`
            * Value: `false`
        * Click "Save".

    * **User 3 (Wants Notifications):**
        * Click "Add document".
        * Document ID: `anotheruser@example.com`
        * Add field:
            * Name: `displayName`
            * Type: `string`
            * Value: `Another Test User`
        * Add field:
            * Name: `marketingNotificationsEnabled`
            * Type: `boolean`
            * Value: `true`
        * Click "Save".

    You now have some test data in your emulated Firestore. The `@example.com` domain is safe to use as it's reserved for documentation and testing and won't result in accidental real email delivery.

---

## Step 3: Write the Cloud Function to "Send" Marketing Emails

Now, let's write an HTTP-triggered Cloud Function that will query your `users` collection and log the emails it *would* send.

1.  **Add the following code to your `functions/index.js` file:**

    ```javascript
    // In functions/index.js

    const functions = require("firebase-functions"); // For older HTTP functions syntax if needed & general config
    const { onRequest } = require("firebase-functions/v2/https"); // For v2 HTTP functions
    const admin = require("firebase-admin");
    const logger = require("firebase-functions/logger"); // Use the new logger

    // Initialize Firebase Admin SDK if not already initialized
    try {
      admin.initializeApp();
    } catch (e) {
      // logger.warn("Admin SDK already initialized or error during initialization:", e);
    }

    const db = admin.firestore(); // Get a Firestore instance

    /**
     * HTTP-triggered function to simulate sending marketing emails.
     * This function queries users with 'marketingNotificationsEnabled' set to true
     * and logs the email content that would be sent.
     */
    exports.sendFakeMarketingEmails = onRequest(
      {
        // Optional: Configure memory, timeout, region for v2 functions
        // memory: "256MiB",
        // timeoutSeconds: 60,
        // region: "us-central1",
      },
      async (request, response) => {
        logger.info("sendFakeMarketingEmails function triggered.");

        try {
          const usersRef = db.collection("users");
          const snapshot = await usersRef
            .where("marketingNotificationsEnabled", "==", true)
            .get();

          if (snapshot.empty) {
            logger.info("No users found with marketing notifications enabled.");
            response.status(200).send("No users to email.");
            return;
          }

          let emailsPreparedCount = 0;
          snapshot.forEach((doc) => {
            const userData = doc.data();
            const userEmail = doc.id; // Document ID is the email address

            // Construct your email content here
            const emailSubject = "🎉 Exciting News & Special Offers Just For You!";
            const emailBody = `
              Hello ${userData.displayName || 'Valued User'},

              We have some fantastic new updates and special promotions we think you'll love!
              Check out our latest deals at [Your Website Here].

              Don't miss out!

              Best,
              The Study Beats Team
            `;

            // Log the email that would be sent
            // This is how you "test if the correct email was received" within the emulator
            logger.info("Marketing Email Prepared (Fake Send):", {
              recipient: userEmail,
              subject: emailSubject,
              bodyPreview: emailBody.substring(0, 100) + "...", // Log a preview
              // fullBody: emailBody, // Optionally log the full body if needed for debugging
              userData: userData,
            });
            emailsPreparedCount++;
          });

          const message = `Successfully prepared ${emailsPreparedCount} fake marketing emails. Check function logs for details.`;
          logger.info(message);
          response.status(200).send(message);

        } catch (error) {
          logger.error("Error in sendFakeMarketingEmails function:", error);
          response.status(500).send("An error occurred. Check function logs.");
        }
      }
    );
    ```

2.  **Save the `functions/index.js` file.**

---

## Step 4: Deploy and Run the Function in the Emulator

The Firebase Emulator Suite automatically hot-reloads your functions when you save changes to `index.js`.

1.  **Check the terminal where `firebase emulators:start` is running.**
    You should see logs indicating that the functions are being updated or reloaded. If there are any syntax errors in your `index.js`, they will appear here.
    Example log: `✔ functions: Loaded functions: sendFakeMarketingEmails.`

2.  **Find the local URL for your `sendFakeMarketingEmails` function.**
    The terminal output from `firebase emulators:start` will list the URLs for your HTTP functions. It will look something like:
    `http://127.0.0.1:5001/YOUR_PROJECT_ID/us-central1/sendFakeMarketingEmails`
    (The region might differ if you specified one).

3.  **Trigger the function:**
    Open this URL in your web browser, or use a tool like `curl` or Postman to send a GET request to it.
    ```bash
    # Example using curl:
    curl [http://127.0.0.1:5001/YOUR_PROJECT_ID/us-central1/sendFakeMarketingEmails](http://127.0.0.1:5001/YOUR_PROJECT_ID/us-central1/sendFakeMarketingEmails)
    ```

---

## Step 5: Testing and Verifying Email "Reception" via Logs

This is where you confirm that your logic correctly identified users and prepared the emails.

1.  **Go to the Emulator UI** in your browser (e.g., `http://127.0.0.1:5002/`).
2.  **Click on the "Logs" tab.**
3.  **Filter for your function:** You can filter the logs to show only those from `sendFakeMarketingEmails`.
4.  **Inspect the logs:** You should see:
    * The initial log: `"sendFakeMarketingEmails function triggered."`
    * For each user with `marketingNotificationsEnabled: true`, you'll see a log entry similar to:
        ```
        Marketing Email Prepared (Fake Send): {
          "recipient": "testuser1@example.com",
          "subject": "🎉 Exciting News & Special Offers Just For You!",
          "bodyPreview": "Hello Test User One,\n\n              We have some fantastic new updates and special promotions we...",
          "userData": {
            "displayName": "Test User One",
            "marketingNotificationsEnabled": true
          }
        }
        ```
    * And another one for `anotheruser@example.com`.
    * You should **not** see an entry for `testuser2@example.com` because their `marketingNotificationsEnabled` is `false`.
    * Finally, a summary log: `"Successfully prepared 2 fake marketing emails. Check function logs for details."`

By examining these logs, you have effectively "tested if the correct email was received" by verifying:
* **Which users were targeted:** The `recipient` field in the log.
* **What content they would have received:** The `subject` and `bodyPreview` fields.

---

This setup allows you to thoroughly test your audience segmentation and email content generation logic entirely within the local emulator environment, without sending any actual emails or incurring costs with third-party email providers during this phase of development.