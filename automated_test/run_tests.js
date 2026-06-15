const fs = require('fs');
const path = require('path');
const { Builder } = require('selenium-webdriver');

// Import test modules
const launchTest = require('./launch_test');
const loginTest = require('./login_test');
const navigationTest = require('./navigation_test');
const salesWasteTest = require('./sales_waste_test');

async function main() {
  const configPath = path.join(__dirname, 'input.json');
  if (!fs.existsSync(configPath)) {
    console.error('[-] Error: input.json not found in automated_test/. Make sure to create it first.');
    process.exit(1);
  }

  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  console.log('[+] Configuration loaded:');
  console.log(`    Base URL:      ${config.baseUrl}`);
  console.log(`    Appium Server: ${config.appiumServer}`);
  console.log(`    Platform:      ${config.platformName}`);
  console.log(`    Device:        ${config.deviceName}`);

  let driver;
  const allResults = [];
  const startTime = Date.now();

  try {
    let builder = new Builder();

    if (config.platformName.toLowerCase() === 'android') {
      console.log('\n[~] Connecting to Appium server...');
      builder = builder.usingServer(config.appiumServer).forBrowser('').withCapabilities({
        browserName: '',
        platformName: 'Android',
        'appium:automationName': 'UiAutomator2',
        'appium:deviceName': config.deviceName,
        'appium:appPackage': config.appPackage,
        'appium:appActivity': config.appActivity,
        'appium:noReset': true,
        'appium:newCommandTimeout': 120,
      });
    } else {
      console.log('\n[~] Starting local Chrome browser...');
      builder = builder.forBrowser('chrome');
    }

    driver = await builder.build();
    console.log('[+] Session established successfully!');

    // Handle browser window dimension setting if not native Android
    if (config.platformName.toLowerCase() !== 'android') {
      await driver.manage().window().setRect({ width: 1000, height: 1000 });
      await driver.get(config.baseUrl);
    }

    // 1. Run Launch Test
    console.log('\n[>] Running: 0. Launch / Smoke Test');
    const launchRes = await launchTest.run(driver, config);
    allResults.push(launchRes);

    // Only proceed if launch succeeded
    if (launchRes.status === 'success') {
      // 2. Run Login Test
      console.log('\n[>] Running: 1. AuthN Bypass / Authentication Test');
      const loginRes = await loginTest.run(driver, config);
      allResults.push(...loginRes);

      // 3. Run Navigation Test
      console.log('\n[>] Running: 3. Navigation Test');
      const navRes = await navigationTest.run(driver, config);
      allResults.push(...navRes);

      // 4. Run Sales & Waste Test
      console.log('\n[>] Running: 4. Sales and Waste Operations Test');
      const swRes = await salesWasteTest.run(driver, config);
      allResults.push(...swRes);
    } else {
      console.warn('[-] Skipping subsequent tests because Launch test failed.');
    }

  } catch (err) {
    console.error('\n[-] Critical Error: Failed to establish automation session.');
    console.error(`    Details: ${err.message}`);
    console.error('\n    [ENVIRONMENT FALLBACK HINT]');
    console.error('    Please ensure that:');
    console.log('    1. The Appium / Selenium server is running (e.g. appium -p 4723)');
    console.log('    2. If testing Android, the emulator is running and adb can discover it (adb devices)');
    console.log('    3. If testing Web, ChromeDriver/Selenium is configured and matches your browser version');
    
    // Log connection failure test entry
    allResults.push({
      endpoint: 'session_init',
      method: 'CONNECT',
      role: 'none',
      status: 'connection_failed',
      expected_status: 'session_established',
      finding: true,
      severity: 'critical',
      response_time_ms: Date.now() - startTime,
      test_category: 'Setup',
      note: `Session connection failed: ${err.message}`,
      timestamp: new Date().toISOString()
    });
  } finally {
    if (driver) {
      try {
        await driver.quit();
        console.log('\n[+] Automation session closed.');
      } catch (e) {}
    }

    // Write report
    const reportPath = path.join(__dirname, 'report.json');
    fs.writeFileSync(reportPath, JSON.stringify(allResults, null, 2));
    console.log(`[+] Full report saved to ${reportPath}`);

    // Print summary
    printSummary(allResults);
  }
}

function printSummary(results) {
  console.log('\n' + '='.repeat(60));
  console.log('                     TEST SUMMARY REPORT');
  console.log('='.repeat(60));

  let total = results.length;
  let passed = 0;
  let failed = 0;
  let findings = 0;

  const categories = {};

  results.forEach(res => {
    const isPass = res.status === 'success' && !res.finding;
    if (isPass) passed++;
    else failed++;

    if (res.finding) findings++;

    if (!categories[res.test_category]) {
      categories[res.test_category] = { total: 0, passed: 0, failed: 0 };
    }
    categories[res.test_category].total++;
    if (isPass) categories[res.test_category].passed++;
    else categories[res.test_category].failed++;
  });

  Object.keys(categories).sort().forEach(cat => {
    console.log(`\nCategory: ${cat}`);
    results.filter(r => r.test_category === cat).forEach(res => {
      const mark = (res.status === 'success' && !res.finding) ? '✓' : (res.finding ? '⚠' : '✗');
      console.log(`  [${mark}] ${res.method} on ${res.endpoint} (${res.response_time_ms}ms)`);
      if (res.note) {
        console.log(`      Note: ${res.note}`);
      }
    });
  });

  console.log('\n' + '='.repeat(60));
  console.log(`Total Scenarios:  ${total}`);
  console.log(`Passed:           ${passed}  ✓`);
  console.log(`Failed/Warnings:  ${failed}  ✗ / ⚠`);
  console.log(`Findings Flagged: ${findings}`);
  console.log('='.repeat(60));
}

main().catch(console.error);
