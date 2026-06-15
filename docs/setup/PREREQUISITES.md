# 1. System Prerequisites Installation Guide

This guide contains the exact copy-pasteable commands to install Node.js, Git, Java JDK, and configure all system environment variables on a Windows machine.

---

### Step 1: Install Node.js, Git, and Java JDK 17
Open a **PowerShell** window and run the following command to download and install all software automatically using the Windows Package Manager (`winget`):

```powershell
# Install Node.js (LTS version)
winget install OpenJS.NodeJS.LTS --silent --accept-source-agreements --accept-package-agreements

# Install Git
winget install Git.Git --silent --accept-source-agreements --accept-package-agreements

# Install Eclipse Temurin JDK 17
winget install EclipseAdoptium.Temurin.17.JDK --silent --accept-source-agreements --accept-package-agreements
```

---

### Step 2: Install Android Studio
1. Open your browser and download the Android Studio installer from:
   **[https://developer.android.com/studio](https://developer.android.com/studio)**
2. Run the installer, accept all default settings, and complete the setup.
3. Open Android Studio once, complete the standard SDK Manager setup (which installs the Android SDK at `%USERPROFILE%\AppData\Local\Android\Sdk` by default).

---

### Step 3: Configure Windows Environment Variables (Exact Commands)
Copy and paste this entire block of code into your **PowerShell** window and press **Enter**. This script will automatically find your SDK folder and configure your system variables permanently:

```powershell
# 1. Set ANDROID_HOME for the current user
[Environment]::SetEnvironmentVariable("ANDROID_HOME", "$env:USERPROFILE\AppData\Local\Android\Sdk", "User")

# 2. Add adb and emulator tools to your User Path
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$adbPath = "%ANDROID_HOME%\platform-tools"
$emulatorPath = "%ANDROID_HOME%\emulator"

$newPath = $currentPath
if ($currentPath -notlike "*%ANDROID_HOME%\platform-tools*") {
    $newPath = "$newPath;$adbPath"
}
if ($currentPath -notlike "*%ANDROID_HOME%\emulator*") {
    $newPath = "$newPath;$emulatorPath"
}

[Environment]::SetEnvironmentVariable("Path", $newPath, "User")

Write-Host "Environment variables configured successfully! Please restart your terminal windows." -ForegroundColor Green
```

---

### Step 4: Verify the Installation
Close all terminal windows, open a **new PowerShell window**, and verify that the tools are available:

```powershell
# Verify Node.js version
node -v

# Verify Git version
git --version

# Verify Java version
java -version

# Verify ADB (Android Debug Bridge) version
adb --version
```
If all commands return versions without errors, proceed to the next guide: **[APPIUM_SETUP.md](./APPIUM_SETUP.md)**.
