# Firebase Emulator Suite: Setup and Test Guide

This guide will walk you through setting up the Firebase Emulator Suite to develop and test your Cloud Functions locally. This is a crucial step before you start implementing features like email marketing, as it allows you to work in a safe environment without affecting live data or services.

## Phase 1: Setting Up Your Firebase Project for Cloud Functions

If you haven't already configured Cloud Functions for your Firebase project, follow these initial steps. If a `functions` folder already exists in your project, you can proceed to Phase 2.

1.  **Ensure Firebase CLI is Installed and You're Logged In:**
    * Open your terminal or command prompt.
    * Install or update the Firebase CLI:
        ```bash
        npm install -g firebase-tools
        ```
    * Log in to Firebase:
        ```bash
        firebase login
        ```

2.  **Navigate to Your Project Root Directory:**
    * In your terminal, change to the root directory of your project (the one containing your `lib` folder, `pubspec.yaml`, etc.).
        ```bash
        cd path/to/your/project
        ```

3.  **Initialize Cloud Functions in Your Firebase Project:**
    * Run the command:
        ```bash
        firebase init functions
        ```
    * **Project Setup:**
        * When prompted "Please select an option", choose "Use an existing project" and select your Firebase project from the provided list.
    * **Language Selection:**
        * When asked, "What language would you like to use to write Cloud Functions?", select **JavaScript** for this initial setup. (You can opt for TypeScript later, which involves an additional build step).
    * **Node.js Version (Important for `engines` field):**
        * During `firebase init functions` or by manually editing `functions/package.json`, you can specify the Node.js version your functions should use. The warning `Your requested "node" version "22" doesn't match your global version "20"` suggests there might be a mismatch or no specific version set in `functions/package.json`. It's good practice to set this in the `engines` field of your `functions/package.json`:
            ```json
            // In functions/package.json
            {
              // ... other properties
              "engines": {
                "node": "20" // Or "18", "16" - choose an LTS version supported by Cloud Functions
              }
              // ...
            }
            ```
            Ensure your local Node.js version (or the version used by the emulator if it differs) aligns with this or is compatible. The emulator log indicates it's falling back to your host's Node 20.
    * **ESLint Configuration:**
        * "Do you want to use ESLint to catch probable bugs and enforce style?" You can type `y` (Yes) or `n` (No). While ESLint is recommended for good practice, selecting 'No' is acceptable for a quick start.
    * **Install Dependencies:**
        * "Do you want to install dependencies with npm now?" Type `y` (Yes).

    This process will generate a `functions` folder in your project root, containing:
    * `index.js`: The file where you will write your Cloud Functions.
    * `package.json`: Manages your function's dependencies (including `firebase-functions` and `firebase-admin`).
    * `node_modules/`: Directory containing the installed dependencies.

## Phase 2: Initializing and Configuring the Firebase Emulators

1.  **Initialize Emulators:**
    * Ensure you are in your project root directory in the terminal.
    * Execute:
        ```bash
        firebase init emulators
        ```
    * **Choose Emulators:**
        * You'll be prompted: "Which Firebase emulators do you want to set up? Press Space to select emulators, then Enter to confirm."
        * Select at least the following:
            * `Functions Emulator`
            * `Firestore Emulator`
            * `Authentication Emulator` (beneficial for user-related functions later)
            * (You may have also selected `Storage Emulator` and `Hosting Emulator` previously)
        * Press `Enter` to confirm your selections.
    * **Port Configuration:**
        * The CLI will suggest default ports for each emulator. In most scenarios, these defaults are suitable. Press `Enter` to accept each default port (e.g., Functions: 5001, Firestore: 8080, Auth: 9099, UI: 4000). *Your log shows Firestore on 8081 and UI on 5002, which is fine if you configured them or they were auto-assigned due to conflicts.*
    * **Enable Emulator UI:**
        * "Do you want to enable the Emulator UI?" Type `y` (Yes). The UI is highly recommended for managing and observing the emulators.
    * **Download Emulators:**
        * "Do you want to download the emulators now?" Type `y` (Yes).

    This step creates or updates the `firebase.json` file in your project root. This file will now include configurations for the emulators, such as their designated ports and paths to rules files.

## Phase 3: Writing Simple Test Cloud Functions

Let's create two basic functions in your `functions/index.js` file. **This section is updated to use the newer syntax for Firestore triggers.**

1.  **Open `functions/index.js`** in your preferred code editor.
2.  **Replace its current content with the following JavaScript code:**

    ```javascript
    // CommonJS imports
    const functions = require("firebase-functions"); // For older HTTP functions syntax if needed & general config
    const { onRequest } = require("firebase-functions/v2/https"); // For v2 HTTP functions
    const { onDocumentCreated } = require("firebase-functions/v2/firestore"); // For v2 Firestore triggers
    const admin = require("firebase-admin");
    const logger = require("firebase-functions/logger"); // Use the new logger

    // Initialize Firebase Admin SDK.
    // This is necessary for functions that interact with Firebase services like Firestore.
    try {
      admin.initializeApp();
    } catch (e) {
      // logger.warn("Admin SDK already initialized or error during initialization:", e);
    }

    /**
     * 1. Simple HTTP-triggered function (v2 syntax).
     * You can test this by visiting its local URL when the emulator is running.
     */
    exports.helloHttp = onRequest((request, response) => {
      logger.info("HTTP Function (v2): helloHttp was called!", {
        query: request.query,
      });
      response.send("Hello from your first emulated HTTP Cloud Function (v2)!");
    });

    /**
     * 2. Simple Firestore-triggered function (v2 syntax).
     * This function will run whenever a new document is created in the
     * 'testCollection' collection in your emulated Firestore.
     * Make sure your document path matches exactly what you intend to trigger on.
     */
    exports.logNewDocument = onDocumentCreated("testCollection/{docId}", (event) => {
      const snap = event.data; // The DocumentSnapshot for the created document
      if (!snap) {
        logger.warn("Firestore Trigger: No data associated with the event for docId:", event.params.docId);
        return;
      }
      const documentData = snap.data();
      const docId = event.params.docId;

      logger.info(
        `Firestore Trigger (v2): New document created in 'testCollection' with ID: ${docId}`,
        {
          documentData: documentData,
        }
      );

      // Example of console logging, though logger is preferred for structured logs
      console.log(
        `Console Log from Firestore Trigger (v2): Document ID ${docId} - Text: ${documentData ? documentData.text : 'N/A'}`
      );

      return null; // Indicates the function finished successfully.
    });
    ```

3.  **Ensure `firebase-admin` and `firebase-functions` are installed:**
    * Navigate into your `functions` directory:
        ```bash
        cd functions
        ```
    * Run:
        ```bash
        npm install firebase-admin firebase-functions
        ```
        (If they are already listed in `package.json`, `npm install` without arguments will ensure all dependencies are met).
    * Return to your project root directory:
        ```bash
        cd ..
        ```

## Phase 4: Running the Emulators

1.  **Start the Emulators:**
    * From your project root directory in the terminal, execute:
        ```bash
        firebase emulators:start
        ```

2.  **Observe the Terminal Output:**
    * The terminal will display output as the emulators initialize.
    * Key information to look for includes:
        * `✔ functions: Emulator started...`
        * `✔ firestore: Emulator started...`
        * `✔ auth: Emulator started...`
        * `✔ ui: Emulator UI available at http://127.0.0.1:5002/` (as per your log)
        * It should also list your functions and their local HTTP trigger URLs.

## Phase 5: Testing Your Cloud Functions

1.  **Test the HTTP Function (`helloHttp`):**
    * Open your web browser.
    * Navigate to the URL provided in the terminal for `helloHttp`. It will look something like: `http://127.0.0.1:5001/your-project-id/us-central1/helloHttp` (adjust the port if your Functions emulator is on a different one, and `your-project-id` with your actual Firebase Project ID).
    * You should see the message: "Hello from your first emulated HTTP Cloud Function (v2)!"
    * Check the terminal where `firebase emulators:start` is running (or the Emulator UI Logs tab). You should see the log message from `logger.info("HTTP Function (v2): helloHttp was called!")`.

2.  **Test the Firestore-Triggered Function (`logNewDocument`):**
    * **Access the Emulator UI:** In your browser, go to `http://127.0.0.1:5002/` (as per your log).
    * **Navigate to the Firestore Tab:** In the Emulator UI, select the "Firestore" tab from the left sidebar (URL should be `http://127.0.0.1:5002/firestore`).
    * **Add Data to Firestore:**
        * Click on "Start collection".
        * For "Collection ID", enter `testCollection`. Click "Next".
        * For "Document ID", you can either click "Auto-ID" or type a custom ID (e.g., `myFirstDoc`).
        * Add a field to the document:
            * Field name: `text`
            * Field type: `string`
            * Field value: `Hello Firestore Emulator (v2)!`
        * (Optional) Add more fields, such as `timestamp` (type `timestamp`, value `current_timestamp`).
        * Click "Save".
    * **Check Logs for Trigger Confirmation:**
        * **Terminal:** Switch back to the terminal window where `firebase emulators:start` is active.
        * **Emulator UI Logs Tab:** In the Emulator UI (`http://127.0.0.1:5002/logs`), you should see log messages from your `logNewDocument` function, similar to:
            * `Firestore Trigger (v2): New document created in 'testCollection' with ID: ...`

## Phase 6: Troubleshooting Common Issues

#### Issue 1: Port Already in Use / Could Not Start Emulator

If you see errors like `Port XXXX is not open on localhost` or `Error: Could not start [Emulator Name] Emulator, port taken`, it means another application on your computer is already using the port that the Firebase Emulator is trying to use.

**Solution 1.1: Find and Stop the Conflicting Process**

* **On macOS or Linux:**
    1.  Open your terminal.
    2.  To find the process using a specific port (e.g., 5000), run:
        ```bash
        sudo lsof -i :5000
        ```
        (Replace `5000` with the problematic port number).
    3.  This command will list the process, including its PID (Process ID).
    4.  To stop the process, use the `kill` command with the PID:
        ```bash
        sudo kill -9 <PID>
        ```
        (Replace `<PID>` with the actual Process ID).

* **On Windows:**
    1.  Open Command Prompt or PowerShell as an administrator.
    2.  To find the process using a specific port (e.g., 5000), run:
        ```bash
        netstat -ano | findstr :5000
        ```
        (Replace `5000` with the problematic port number).
    3.  Look at the last column for the PID (Process ID).
    4.  To stop the process, use `taskkill`:
        ```bash
        taskkill /PID <PID> /F
        ```
        (Replace `<PID>` with the actual Process ID. `/F` forces the process to terminate).

After stopping the conflicting process, try running `firebase emulators:start` again.

**Solution 1.2: Change Emulator Ports in `firebase.json`**

If you cannot stop the other process or prefer to use different ports for the emulators, you can configure them in your `firebase.json` file.

1.  Open the `firebase.json` file located in your project root directory.
2.  Look for the `emulators` section.
3.  Change the `port` value for the emulators that are causing conflicts.
    Example `firebase.json` with adjusted ports:
    ```json
    {
      "emulators": {
        "auth": { "port": 9099 },
        "functions": { "port": 5001 },
        "firestore": { "port": 8080 },
        "hosting": { "port": 5005 }, // Changed from 5000
        "ui": {
          "enabled": true,
          "port": 4001 // Changed from 4000
        },
        "storage": { "port": 9199 }
        // ... other emulators
      }
    }
    ```
4.  Save the `firebase.json` file and try `firebase emulators:start` again.

#### Issue 2: Storage Emulator - Rules File Missing

If you see an error like `Error: Cannot start the Storage emulator without rules file specified in firebase.json...`.

**Solution 2.1: Initialize Storage and Create Default Rules (Recommended if using Storage)**
1.  In your project root, run:
    ```bash
    firebase init storage
    ```
2.  Accept the default file name (`storage.rules`) when prompted. This creates the file and updates `firebase.json`.
3.  A `storage.rules` file will be created, typically with permissive rules like:
    ```
    rules_version = '2';
    service firebase.storage {
      match /b/{bucket}/o {
        match /{allPaths=**} {
          allow read, write: if true; // WARNING: Open to public
        }
      }
    }
    ```
    *Caution: These default rules are open. For production, you must write secure rules.*
4.  Try `firebase emulators:start` again.

**Solution 2.2: Disable the Storage Emulator (If not needed for current task)**
1.  If you don't need the Storage emulator for your current development task, you can prevent it from starting.
2.  Edit your `firebase.json` and remove or comment out the `storage` section within `emulators`:
    ```json
    {
      "emulators": {
        // ... other emulators ...
        // "storage": {
        //   "port": 9199 // Or whatever port it was using
        // }
      }
    }
    ```
3.  Alternatively, use the `--only` flag when starting emulators:
    ```bash
    firebase emulators:start --only functions,firestore,auth,ui # Add other emulators you need
    ```

#### Issue 3: Firestore Emulator - Rules File Missing (Warning)

If you see a warning like `Did not find a Cloud Firestore rules file specified... The emulator will default to allowing all reads and writes.`, it's advisable to set up rules for the Firestore emulator.

**Solution 3.1: Initialize Firestore Rules**
1.  In your project root, run:
    ```bash
    firebase init firestore
    ```
2.  Accept the default file names for rules (`firestore.rules`) and indexes (`firestore.indexes.json`).
3.  This creates the files and updates `firebase.json`. The default `firestore.rules` will be similar to:
    ```
    rules_version = '2';
    service cloud.firestore {
      match /databases/{database}/documents {
        match /{document=**} {
          allow read, write: if false; // Or 'if request.auth != null;' for authenticated access
        }
      }
    }
    ```
    *Modify these rules as needed for your application. For local testing, you might temporarily set it to `allow read, write: if true;` but ensure production rules are secure.*

#### Issue 4: `TypeError: functions.firestore.document is not a function` or Functions Not Loading

This typically means the syntax for defining your Cloud Function (especially event-triggered ones like Firestore) is incorrect for the installed version of `firebase-functions`.

**Solution 4.1: Use Correct v2 SDK Syntax**
* Ensure your `functions/index.js` uses the v2 SDK syntax as shown in the updated **Phase 3** of this guide.
    * Import triggers like `const { onDocumentCreated } = require("firebase-functions/v2/firestore");`
    * Define functions like `exports.myFunction = onDocumentCreated("collection/{docId}", (event) => { ... });`
* Use `firebase-functions/logger` for logging (e.g., `logger.info()`, `logger.error()`).
* Make sure `firebase-admin` and `firebase-functions` are correctly installed in your `functions/node_modules` directory. If in doubt, navigate to the `functions` directory and run `npm install`.

**Well Done!** You have now successfully configured the Firebase Emulator Suite and tested both an HTTP-triggered and a Firestore-triggered Cloud Function locally.

**To Stop the Emulators:**
* Return to the terminal window where the emulators are running and press `Ctrl + C`.
