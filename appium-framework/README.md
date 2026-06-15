# SmartMenu Appium E2E Automation Framework

This project contains an End-to-End (E2E) mobile test automation framework for the real SmartMenu Flutter Android APK using Appium 2.x and Node.js.

## Directory Structure

```
appium-framework/
├── config/
│   └── capabilities.js   # Desired capabilities configurations
├── pages/
│   ├── basePage.js       # Base Page Object with coordinate calculations
│   ├── loginPage.js      # Login screen elements and methods
│   └── dashboardPage.js  # Dashboard navigation and sales dialog methods
├── tests/
│   ├── baseSetup.js      # Global before/after test hooks (saves logcats & screenshots)
│   ├── login.test.js     # Authentication test suite
│   └── navigation.test.js# Navigation and CRUD operations test suite
├── utilities/
│   ├── driverFactory.js  # Manages driver instances & adb device detection
│   ├── gestures.js       # Custom pointer action / native appium gesture layer
│   ├── logger.js         # Winston console & file log system
│   ├── reporter.js       # ExcelJS custom 4-sheet reporter
│   └── waits.js          # Explicit wait wrappers
├── logs/
│   └── appium-tests.log  # Run-by-run logs
├── reports/
│   ├── Mobile_E2E_Report.xlsx # 4-sheet excel report output
│   ├── mochawesome/      # HTML reporting folder
│   └── failures/         # Capture folder for failure screenshots and logcats
├── .mocharc.json         # Mocha configuration file
├── package.json          # Node dependencies
└── README.md             # This document
```

---

## Local Setup Prerequisites

### 1. System Requirements
- **Node.js**: v18.x or later
- **Java Development Kit (JDK)**: JDK 11 or JDK 17
- **Android SDK**: With platform tools (`adb`), emulator system images, and command line tools configured in system PATH (`ANDROID_HOME`).

### 2. Appium Setup
Ensure Appium 2.x and the UiAutomator2 driver are installed globally:
```bash
npm install -g appium@latest
appium driver install uiautomator2
```

### 3. Install Project Dependencies
Navigate to the framework folder and install package dependencies:
```bash
cd appium-framework
npm install
```

---

## Configuration & Environment Variables

Create a `.env` file in `appium-framework/` or export variables directly:

```env
# Server details
APPIUM_SERVER=http://127.0.0.1:4723
BASE_URL=http://127.0.0.1:50379

# Execution mode: set USE_APK to true to install/launch APK, false to test pre-installed
USE_APK=false
APK_PATH=../flutter_app/build/app/outputs/flutter-apk/app-debug.apk
APP_PACKAGE=com.example.flutter_app
APP_ACTIVITY=.MainActivity

# Credentials
TEST_EMAIL=madhuhawk79@gmail.com
TEST_PASSWORD=ikmdmad7

# Logging level (info, debug, warn, error)
LOG_LEVEL=info
```

---

## Running Tests

### 0. Build the real Flutter APK
The tests should run against the real Flutter app, not the old demo wrapper. From the workspace root:

```bash
cd flutter_app
.\build_apk.ps1
```

This reads `flutter_app/.env` and passes Firebase/API values into the APK through Flutter dart-defines.

### 1. Start Appium Server
```bash
appium --port 4723
```

### 2. Run an Android Emulator or Connect a Real Device
Ensure your device or emulator is connected. Verify with:
```bash
adb devices
```

### 3. Execute mocha suite
```bash
npm run test
```

---

## Reports and Logs

After test execution, the following files will be automatically generated:
1. **Excel Spreadsheet**: `reports/Mobile_E2E_Report.xlsx`
   - **Summary**: Date, device stats, passed/failed/skipped stats.
   - **Test Cases**: ID, scenario, start/end time, duration, and status.
   - **Failed Tests**: Stack trace, screenshot paths, and current activity details.
   - **Execution Logs**: Detailed step-by-step logs for verification.
2. **HTML report**: `reports/mochawesome/mochawesome-report.html`
3. **Screenshots & Logs (On Failures)**: Stored under `reports/failures/`
   - `<test_name>_failed.png`
   - `<test_name>_logcat.txt`
   - `<test_name>_source.xml`
4. **General logs**: `logs/appium-tests.log`

The framework also performs a non-blank screenshot check during assertions. If the app shows a white/blank screen, the test fails instead of producing a false green report.
