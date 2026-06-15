# 2. Appium & SSL Bypass Setup Guide

This guide details the exact commands to install Appium 2.x and resolve the **Avast / McAfee HTTPS SSL PKIX path building** error on Windows.

---

### Step 1: Install Appium and UiAutomator2 Driver
Open a **PowerShell** window and run these commands to install Appium and its Android driver globally:

```powershell
# 1. Install Appium 2.x globally
npm install -g appium@latest

# 2. Install the Android UiAutomator2 driver
appium driver install uiautomator2
```

---

### Step 2: Fix the SSL PKIX Error (Bypass Antivirus Blockage)
If your junior's machine has **Avast** or **McAfee** installed, their Gradle builds will fail with a `PKIX path building failed` error. 

Copy and paste this entire PowerShell script to export the antivirus certificate from the Windows store and import it into a custom Java trust store inside their user folder:

```powershell
# 1. Copy the Java default truststore to their user profile folder
Copy-Item -Path "C:\Program Files\Android\Android Studio\jbr\lib\security\cacerts" -Destination "$env:USERPROFILE\custom_cacerts" -Force

# 2. Locate the Avast/McAfee Root CA Certificate in the Windows store
$avastCert = Get-ChildItem -Path Cert:\LocalMachine\Root, Cert:\CurrentUser\Root | Where-Object { $_.Subject -match "Avast" -or $_.Subject -match "McAfee" -or $_.Subject -match "WebAdvisor" } | Select-Object -First 1

if ($avastCert) {
    # 3. Export the certificate to the temp folder
    Export-Certificate -Cert $avastCert -FilePath "$env:TEMP\antivirus_root.cer"
    
    # 4. Import the certificate into the custom truststore
    & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -importcert -trustcacerts -file "$env:TEMP\antivirus_root.cer" -keystore "$env:USERPROFILE\custom_cacerts" -storepass changeit -alias antivirus_root -noprompt
    
    # Clean up temporary certificate file
    Remove-Item "$env:TEMP\antivirus_root.cer" -Force
    
    Write-Host "SUCCESS: Custom truststore created at $env:USERPROFILE\custom_cacerts with Antivirus certificate!" -ForegroundColor Green
} else {
    Write-Host "No Avast/McAfee root certificates found. Custom truststore setup skipped." -ForegroundColor Yellow
}
```

---

### Step 3: Configure `gradle.properties` with Their Username
Because Gradle properties require absolute paths and do not support environment variable expansion, **each developer must update their local `gradle.properties` file** to match their Windows username.

1. Open `flutter_app/android/gradle.properties`.
2. Locate these two lines at the bottom:
   ```properties
   systemProp.javax.net.ssl.trustStore=C:/Users/mmadh/custom_cacerts
   systemProp.javax.net.ssl.trustStorePassword=changeit
   ```
3. Change `mmadh` to the junior developer's Windows username (e.g. `C:/Users/john/custom_cacerts`).

---

### Step 4: Verify Appium
Run this command to check that Appium and the UiAutomator2 driver are loaded correctly:

```powershell
appium
```
It should print:
`[Appium] Welcome to Appium v3.x.x`
`[Appium] Available drivers:`
`[Appium]   - uiautomator2@x.x.x (automationName 'UiAutomator2')`

Press **Ctrl + C** to close Appium, and proceed to the final guide: **[RUN_TESTS.md](./RUN_TESTS.md)**.
