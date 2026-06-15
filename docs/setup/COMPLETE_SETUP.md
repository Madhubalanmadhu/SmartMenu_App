# SmartMenu Master E2E Setup & Execution Guide

This guide contains the exact copy-pasteable script to set up a new Windows laptop for SmartMenu E2E testing, followed by the commands to run the test suite.

---

## Part 1: Automated Environment Setup (Single Script)
Open **PowerShell as Administrator** on the junior developer's laptop, copy the entire block below, paste it, and press **Enter**:

```powershell
# 1. Install prerequisites (Node, Git, JDK 17)
Write-Host "Installing Node.js, Git, and JDK 17..." -ForegroundColor Green
winget install OpenJS.NodeJS.LTS --silent --accept-source-agreements --accept-package-agreements
winget install Git.Git --silent --accept-source-agreements --accept-package-agreements
winget install EclipseAdoptium.Temurin.17.JDK --silent --accept-source-agreements --accept-package-agreements

# 2. Configure Environment Variables permanently for the current user
Write-Host "Configuring environment variables..." -ForegroundColor Green
[Environment]::SetEnvironmentVariable("ANDROID_HOME", "$env:USERPROFILE\AppData\Local\Android\Sdk", "User")
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$adbPath = "%ANDROID_HOME%\platform-tools"
$emulatorPath = "%ANDROID_HOME%\emulator"
$newPath = $currentPath
if ($currentPath -notlike "*%ANDROID_HOME%\platform-tools*") { $newPath = "$newPath;$adbPath" }
if ($currentPath -notlike "*%ANDROID_HOME%\emulator*") { $newPath = "$newPath;$emulatorPath" }
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")

# 3. Install Appium 2.x and UiAutomator2 driver globally
Write-Host "Installing Appium..." -ForegroundColor Green
npm install -g appium@latest
appium driver install uiautomator2

# 4. Copy Java truststore and import Avast/McAfee SSL certificate if found
Write-Host "Setting up custom Java truststore for Antivirus SSL bypass..." -ForegroundColor Green
Copy-Item -Path "C:\Program Files\Android\Android Studio\jbr\lib\security\cacerts" -Destination "$env:USERPROFILE\custom_cacerts" -Force
$avastCert = Get-ChildItem -Path Cert:\LocalMachine\Root, Cert:\CurrentUser\Root | Where-Object { $_.Subject -match "Avast" -or $_.Subject -match "McAfee" -or $_.Subject -match "WebAdvisor" } | Select-Object -First 1
if ($avastCert) {
    Export-Certificate -Cert $avastCert -FilePath "$env:TEMP\antivirus_root.cer"
    & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -importcert -trustcacerts -file "$env:TEMP\antivirus_root.cer" -keystore "$env:USERPROFILE\custom_cacerts" -storepass changeit -alias antivirus_root -noprompt
    Remove-Item "$env:TEMP\antivirus_root.cer" -Force
    Write-Host "SUCCESS: Custom truststore configured at $env:USERPROFILE\custom_cacerts!" -ForegroundColor Green
} else {
    Write-Host "No Avast/McAfee certificates found in Windows store. Clean truststore created." -ForegroundColor Yellow
}

Write-Host "==============================================================================" -ForegroundColor Green
Write-Host "SETUP COMPLETE! Please close this terminal and open a new one to run tests." -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green
```

---

## Part 2: Local Project Configuration
Because Gradle properties require absolute paths, **update the username in the local project settings**:

1. Open `flutter_app/android/gradle.properties`.
2. Locate these two lines at the bottom:
   ```properties
   systemProp.javax.net.ssl.trustStore=C:/Users/mmadh/custom_cacerts
   systemProp.javax.net.ssl.trustStorePassword=changeit
   ```
3. Change `mmadh` to the junior developer's Windows username (e.g. `C:/Users/john/custom_cacerts`).

---

## Part 3: Running the E2E Tests

### Step 1: Rebuild the Flutter Android APK
Open a **new PowerShell window**, navigate to the `flutter_app` folder, and compile the debug APK:

```powershell
cd "S:\rest pdd\flutter_app"
.\build_apk.ps1
```

### Step 2: Clear Old Appium Helper Apps from Phone
Plug the phone into the PC, make sure USB Debugging is ON, and run:

```powershell
adb uninstall io.appium.settings
adb uninstall io.appium.uiautomator2.server
adb uninstall io.appium.uiautomator2.server.test
```

### Step 3: Start Appium Server (Terminal 1)
Open a **new PowerShell window** (Terminal 1) and run:

```powershell
$env:ANDROID_HOME="C:\Users\mmadh\AppData\Local\Android\Sdk"
appium --port 4723
```
*(Replace `mmadh` with your Windows username in the path above if needed)*

### Step 4: Execute the Tests (Terminal 2)
Open another **new PowerShell window** (Terminal 2) and run:

```powershell
cd "S:\rest pdd\appium-framework"
$env:ANDROID_HOME="C:\Users\mmadh\AppData\Local\Android\Sdk"
$env:USE_APK="true"
npm run test
```
*(Replace `mmadh` with your Windows username in the path above if needed. When prompted on your phone, tap **Allow / Install** immediately to grant Appium permissions).*
