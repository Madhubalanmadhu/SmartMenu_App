const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const DriverFactory = require('../utilities/driverFactory');
const logger = require('../utilities/logger');
const { globalReporter } = require('../utilities/reporter');
const { getAppPackage } = require('../config/capabilities');

let driver;
let testStartTime;

before(async function() {
  this.timeout(180000);
  logger.info('=== Starting Mobile Automation Test Suite ===');
  
  try {
    driver = await DriverFactory.createDriver();
    this.driver = driver;
    logger.info('Test driver injected successfully.');
  } catch (error) {
    logger.error(`Base setup failure during driver creation: ${error.message}`);
    throw error;
  }
});

beforeEach(async function() {
  testStartTime = Date.now();
  const testName = this.currentTest ? this.currentTest.fullTitle() : 'Unknown';
  logger.info(`>>> Running Test: ${testName}`);
  if (driver) {
    try {
      await driver.executeScript('mobile: activateApp', { appId: getAppPackage() });
      await driver.sleep(750);
    } catch (error) {
      logger.warn(`App foreground check skipped: ${error.message}`);
    }
  }
  globalReporter.addLogRecord({
    testName,
    step: 'Test Init',
    result: 'INFO',
    remarks: 'Test started.'
  });
});

afterEach(async function() {
  const test = this.currentTest;
  const testName = test ? test.fullTitle() : 'Unknown';
  const duration = Date.now() - testStartTime;
  const status = test.state === 'passed' ? 'Passed' : 'Failed';
  
  logger.info(`<<< Finished Test: ${testName} | Status: ${status} | Duration: ${duration}ms`);

  // Log test outcome to Excel testcases sheet
  globalReporter.addTestRecord({
    testId: test.title.split(' ')[0] || `TC_${Date.now()}`,
    module: test.parent ? test.parent.title : 'Global',
    scenario: test.title,
    device: process.env.DEVICE_NAME || 'Android Emulator',
    status,
    startTime: new Date(testStartTime),
    endTime: new Date(),
    duration
  });

  if (test.state === 'failed') {
    logger.error(`Test FAILED: ${testName}`);
    logger.error(`Reason: ${test.err.message}`);

    const failureDir = path.resolve(__dirname, '../reports/failures');
    if (!fs.existsSync(failureDir)) {
      fs.mkdirSync(failureDir, { recursive: true });
    }

    const sanitizedName = testName.replace(/[^a-z0-9]/gi, '_').toLowerCase();
    
    // 1. Capture Screenshot
    let screenshotPath = 'N/A';
    try {
      const screenshotData = await driver.takeScreenshot();
      const filename = `${sanitizedName}_failed.png`;
      const fullPath = path.join(failureDir, filename);
      fs.writeFileSync(fullPath, screenshotData, 'base64');
      screenshotPath = fullPath;
      logger.info(`Screenshot captured: ${screenshotPath}`);
    } catch (e) {
      logger.error(`Failed to capture screenshot: ${e.message}`);
    }

    // 2. Capture Device Logs (logcat)
    let logcatPath = 'N/A';
    try {
      // Use adb logcat to get recent logs
      const udid = process.env.UDID ? `-s ${process.env.UDID} ` : '';
      const logcatLogs = execSync(`adb ${udid}logcat -d -v time *:E`, { encoding: 'utf8' });
      const filename = `${sanitizedName}_logcat.txt`;
      const fullPath = path.join(failureDir, filename);
      fs.writeFileSync(fullPath, logcatLogs);
      logcatPath = fullPath;
      logger.info(`Logcat logs captured: ${logcatPath}`);
    } catch (e) {
      logger.error(`Failed to capture logcat: ${e.message}`);
    }

    // 3. Get Current Activity
    let activityName = 'N/A';
    try {
      activityName = await driver.getCurrentActivity();
    } catch (e) {
      try {
        const udid = process.env.UDID ? `-s ${process.env.UDID} ` : '';
        const adbFocus = execSync(`adb ${udid}shell dumpsys window`, { encoding: 'utf8' });
        const focusLine = adbFocus
          .split(/\r?\n/)
          .find(line => line.includes('mCurrentFocus') || line.includes('mFocusedApp'));
        activityName = focusLine ? focusLine.trim() : 'Unknown Activity';
      } catch (e2) {
        activityName = 'Unknown Activity';
      }
    }
    logger.info(`Current Activity on failure: ${activityName}`);

    // 4. Get XML Source Layout
    try {
      const xmlSource = await driver.getPageSource();
      const filename = `${sanitizedName}_source.xml`;
      fs.writeFileSync(path.join(failureDir, filename), xmlSource);
    } catch (e) {
      logger.error(`Failed to capture XML layout: ${e.message}`);
    }

    // Record failure details in Excel report
    globalReporter.addFailureRecord({
      testName,
      reason: test.err.stack || test.err.message,
      screenshotPath,
      device: process.env.DEVICE_NAME || 'Android Emulator',
      androidVersion: process.env.ANDROID_VERSION || '13',
      activityName
    });

    globalReporter.addLogRecord({
      testName,
      step: 'Failure Teardown',
      result: 'FAILED',
      remarks: `Reason: ${test.err.message}. Screenshot saved to ${screenshotPath}`
    });
  } else {
    globalReporter.addLogRecord({
      testName,
      step: 'Success Teardown',
      result: 'PASSED',
      remarks: 'Test executed successfully.'
    });
  }
});

after(async function() {
  this.timeout(60000);
  logger.info('=== Tearing Down Mobile Automation Test Suite ===');
  
  if (driver) {
    try {
      await driver.quit();
      logger.info('Appium session closed.');
    } catch (error) {
      logger.error(`Failed to quit Appium driver: ${error.message}`);
    }
  }

  // Generate the Excel Sheet and CSV Reports
  try {
    const device = process.env.DEVICE_NAME || 'Android Emulator';
    const version = process.env.ANDROID_VERSION || '13';
    await globalReporter.generateExcelReport(device, version);
    await globalReporter.generateCSVReport();
    await globalReporter.generateTestingLogsCSV(30);
  } catch (error) {
    logger.error(`Failed to write Reports: ${error.message}`);
  }
});

module.exports = {
  getDriver: () => driver
};
