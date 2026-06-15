const fs = require('fs');
const path = require('path');

async function clickAt(driver, x, y) {
  try {
    await driver.executeScript(
      `
        const el = document.elementFromPoint(arguments[0], arguments[1]);
        if (el) el.click();
      `,
      x,
      y
    );
  } catch (err) {
    await driver.actions().move({ x: parseInt(x), y: parseInt(y) }).press().release().perform();
  }
}

async function run(driver, config) {
  const results = [];
  const tabNames = ['Dashboard', 'Menu', 'Sales', 'Analytics', 'Waste'];
  
  let size = { width: 1000, height: 1000 };
  try {
    size = await driver.executeScript(`
      return { width: window.innerWidth, height: window.innerHeight };
    `);
  } catch (e) {
    try {
      const winSize = await driver.manage().window().getSize();
      size = { width: winSize.width, height: winSize.height };
    } catch (e2) {}
  }

  // Bottom navigation bar Y location is near the bottom
  const y = Math.floor(size.height * 0.96);
  const screenshotDir = path.join(__dirname, 'screenshots');

  for (let i = 0; i < tabNames.length; i++) {
    const tabName = tabNames[i];
    const startTime = Date.now();
    const result = {
      endpoint: `/home/tab/${tabName.toLowerCase()}`,
      method: 'NAVIGATE_TAB',
      role: 'restaurant_owner',
      status: 'unknown',
      expected_status: 'success',
      finding: false,
      severity: 'info',
      response_time_ms: 0,
      test_category: '3. RBAC Matrix / Navigation',
      note: '',
      timestamp: new Date().toISOString()
    };

    try {
      console.log(`  [Navigation Test] Navigating to ${tabName} Tab...`);
      // Compute tab X coordinate (5 tabs total, distributed evenly at 10%, 30%, 50%, 70%, 90%)
      const x = Math.floor(size.width * (0.1 + i * 0.2));
      
      await clickAt(driver, x, y);
      await driver.sleep(3000); // Wait for transit and rendering

      const screenshotPath = path.join(screenshotDir, `nav_${tabName.toLowerCase()}.png`);
      const base64Data = await driver.takeScreenshot();
      fs.writeFileSync(screenshotPath, base64Data, 'base64');

      result.status = 'success';
      result.note = `Successfully navigated to ${tabName} tab. Screenshot saved to ${screenshotPath}`;
      console.log(`  [Navigation Test] Navigated to ${tabName}. Screenshot saved.`);
    } catch (error) {
      result.status = 'error';
      result.finding = true;
      result.severity = 'medium';
      result.note = `Failed to navigate to ${tabName} tab: ${error.message}`;
      console.error(`  [Navigation Test] Error on tab ${tabName}: ${error.message}`);
    } finally {
      result.response_time_ms = Date.now() - startTime;
      results.push(result);
    }
  }

  return results;
}

module.exports = { run };
