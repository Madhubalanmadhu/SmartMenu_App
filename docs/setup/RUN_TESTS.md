# 3. Running E2E Test Suite Guide

This guide details the exact sequence of commands to build the Flutter APK, start the Appium server, and execute the automated E2E test suite.

---

### Step 1: Rebuild the Flutter Android APK
Open a **PowerShell** window, navigate to the `flutter_app` folder, and compile the debug APK:

```powershell
cd "S:\rest pdd\flutter_app"
.\build_apk.ps1
```

This generates the native APK configured with all `.env` credentials at `flutter_app\build\app\outputs\flutter-apk\app-debug.apk`.

---

### Step 2: Connect Phone and Clean Appium Helpers
1. Plug your Android phone into the PC using a USB cable.
2. Verify that ADB detects your phone:
   ```powershell
   adb devices
   ```
   *(Ensure your device ID is listed under "List of devices attached")*
3. Run these cleanup commands to completely wipe out any old or corrupt Appium settings apps (crucial for phones with Dual Apps / Work Profiles active):
   ```powershell
   adb uninstall io.appium.settings
   adb uninstall io.appium.uiautomator2.server
   adb uninstall io.appium.uiautomator2.server.test
   ```

---

### Step 3: Start the Appium Server (Terminal 1)
Open a **new PowerShell window** (Terminal 1) and run:

```powershell
$env:ANDROID_HOME="C:\Users\mmadh\AppData\Local\Android\Sdk"
appium --port 4723
```

---

### Step 4: Run the Test Suite (Terminal 2)
Open another **new PowerShell window** (Terminal 2) and run:

```powershell
cd "S:\rest pdd\appium-framework"
$env:ANDROID_HOME="C:\Users\mmadh\AppData\Local\Android\Sdk"
$env:USE_APK="true"
npm run test
```

---

### Step 5: Viewing Reports and Logs
After the tests complete, you can find the outputs at these locations:
* **Excel Test Report**: **[Mobile_E2E_Report.xlsx](file:///S:/rest%20pdd/appium-framework/reports/Mobile_E2E_Report.xlsx)** (Open this spreadsheet to see test execution details).
* **HTML Test Report**: `appium-framework\reports\mochawesome\mochawesome-report.html` (Open this file in your browser to see a visual report of the run).
* **Run Logs**: `appium-framework\logs\appium-tests.log` (Check this log file if any tests failed to see why).
* **Failure Screenshots**: `appium-framework\reports\failures\` (Contains screenshots captured automatically if any test step fails).
