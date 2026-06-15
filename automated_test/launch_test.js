const fs = require('fs');
const path = require('path');

async function run(driver, config) {
  const startTime = Date.now();
  const result = {
    endpoint: '/login',
    method: 'LAUNCH_APP',
    role: 'anonymous',
    status: 'unknown',
    expected_status: 'success',
    finding: false,
    severity: 'info',
    response_time_ms: 0,
    test_category: '0. Launch / Smoke Test',
    note: '',
    timestamp: new Date().toISOString()
  };

  try {
    console.log('  [Launch Test] Waiting for app to settle...');
    await driver.sleep(8000);

    const screenshotDir = path.join(__dirname, 'screenshots');
    if (!fs.existsSync(screenshotDir)) {
      fs.mkdirSync(screenshotDir, { recursive: true });
    }
    
    const screenshotPath = path.join(screenshotDir, 'launch.png');
    const base64Data = await driver.takeScreenshot();
    fs.writeFileSync(screenshotPath, base64Data, 'base64');
    
    const sourcePath = path.join(screenshotDir, 'launch-source.xml');
    const source = await driver.getPageSource();
    fs.writeFileSync(sourcePath, source);
    
    result.status = 'success';
    result.note = `App launched successfully. Screenshot saved to ${screenshotPath}`;
    console.log('  [Launch Test] App launched successfully. Screenshot saved.');
  } catch (error) {
    result.status = 'error';
    result.finding = true;
    result.severity = 'critical';
    result.note = `Failed to launch app: ${error.message}`;
    console.error(`  [Launch Test] Error: ${error.message}`);
  } finally {
    result.response_time_ms = Date.now() - startTime;
  }
  return result;
}

module.exports = { run };
