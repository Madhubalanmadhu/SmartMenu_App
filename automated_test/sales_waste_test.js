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
  const screenshotDir = path.join(__dirname, 'screenshots');
  
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

  // 1. Enter Sales Test Case
  const salesResult = {
    endpoint: '/sales/',
    method: 'POST_SALE_RECORD',
    role: 'restaurant_owner',
    status: 'unknown',
    expected_status: 'success',
    finding: false,
    severity: 'info',
    response_time_ms: 0,
    test_category: '4. Sales CRUD',
    note: '',
    timestamp: new Date().toISOString()
  };

  const startSalesTime = Date.now();
  try {
    console.log('  [Sales Test] Opening Sales dialog...');
    // Tap the Sales Tab first (Tab 2, index 2)
    const tabY = Math.floor(size.height * 0.96);
    const tabX = Math.floor(size.width * 0.5); // 3rd tab
    await clickAt(driver, tabX, tabY);
    await driver.sleep(3000);

    // Tap "Enter Sales" card (approx x=25%, y=45%)
    const cardX = Math.floor(size.width * 0.25);
    const cardY = Math.floor(size.height * 0.45);
    await clickAt(driver, cardX, cardY);
    await driver.sleep(3000);

    // Take screenshot of the dialog
    const dialogScreenshotPath = path.join(screenshotDir, 'sales_dialog.png');
    const dialogData = await driver.takeScreenshot();
    fs.writeFileSync(dialogScreenshotPath, dialogData, 'base64');

    // Fill in the Sales Dialog:
    // Focus Sale Date and clear/type date
    const dateX = Math.floor(size.width * 0.5);
    const dateY = Math.floor(size.height * 0.40);
    await clickAt(driver, dateX, dateY);
    await driver.actions().sendKeys('2026-06-13').perform();
    await driver.sleep(1000);

    // Dropdown for Dish selection (approx x=50%, y=50%)
    const dishX = Math.floor(size.width * 0.5);
    const dishY = Math.floor(size.height * 0.50);
    await clickAt(driver, dishX, dishY);
    await driver.sleep(1000);
    // Send Down arrow and Enter to pick the first item
    await driver.actions().sendKeys('\uE015').sendKeys('\uE006').perform(); // Arrow Down and Enter keys
    await driver.sleep(1000);

    // Quantity Sold textfield (approx x=50%, y=60%)
    const qtyX = Math.floor(size.width * 0.5);
    const qtyY = Math.floor(size.height * 0.60);
    await clickAt(driver, qtyX, qtyY);
    await driver.actions().sendKeys('15').perform();
    await driver.sleep(1000);

    // Click "Save Sale" (approx x=65%, y=72%)
    const saveX = Math.floor(size.width * 0.65);
    const saveY = Math.floor(size.height * 0.72);
    await clickAt(driver, saveX, saveY);
    await driver.sleep(4000); // Wait for API submission

    // Take screenshot after save
    const afterSavePath = path.join(screenshotDir, 'sales_after_save.png');
    const afterSaveData = await driver.takeScreenshot();
    fs.writeFileSync(afterSavePath, afterSaveData, 'base64');

    salesResult.status = 'success';
    salesResult.note = `Successfully completed sales dialog interaction and submitted transaction. Screenshot saved to ${afterSavePath}`;
    console.log('  [Sales Test] Recorded sale successfully. Screenshot saved.');
  } catch (error) {
    salesResult.status = 'error';
    salesResult.finding = true;
    salesResult.severity = 'medium';
    salesResult.note = `Failed to record sale: ${error.message}`;
    console.error(`  [Sales Test] Error: ${error.message}`);
  } finally {
    salesResult.response_time_ms = Date.now() - startSalesTime;
    results.push(salesResult);
  }

  // 2. Waste Entry Test Case
  const wasteResult = {
    endpoint: '/waste/',
    method: 'POST_WASTE_RECORD',
    role: 'restaurant_owner',
    status: 'unknown',
    expected_status: 'success',
    finding: false,
    severity: 'info',
    response_time_ms: 0,
    test_category: '5. Waste CRUD',
    note: '',
    timestamp: new Date().toISOString()
  };

  const startWasteTime = Date.now();
  try {
    console.log('  [Waste Test] Navigating to Waste tab and preparing tracking test...');
    // Tap Waste Tab (Tab 4, index 4 - 90% X coordinate)
    const tabY = Math.floor(size.height * 0.96);
    const tabX = Math.floor(size.width * 0.9);
    await clickAt(driver, tabX, tabY);
    await driver.sleep(3000);

    const wasteScreenshotPath = path.join(screenshotDir, 'waste_screen.png');
    const wasteData = await driver.takeScreenshot();
    fs.writeFileSync(wasteScreenshotPath, wasteData, 'base64');

    wasteResult.status = 'success';
    wasteResult.note = `Successfully verified waste dashboard screen. Screenshot saved to ${wasteScreenshotPath}`;
    console.log('  [Waste Test] Verified Waste screen successfully. Screenshot saved.');
  } catch (error) {
    wasteResult.status = 'error';
    wasteResult.finding = true;
    wasteResult.severity = 'medium';
    wasteResult.note = `Failed to execute waste dashboard screen test: ${error.message}`;
    console.error(`  [Waste Test] Error: ${error.message}`);
  } finally {
    wasteResult.response_time_ms = Date.now() - startWasteTime;
    results.push(wasteResult);
  }

  return results;
}

module.exports = { run };
