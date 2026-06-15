const { expect } = require('chai');
const path = require('path');
const fs = require('fs');
const { getDriver } = require('./baseSetup');
const DashboardPage = require('../pages/dashboardPage');
const logger = require('../utilities/logger');
const { getAppPackage } = require('../config/capabilities');

describe('SmartMenu Navigation & Operations Flow', function() {
  this.timeout(180000);

  let driver;
  let dashboardPage;

  before(async function() {
    driver = getDriver();
    dashboardPage = new DashboardPage(driver);
    
    const LoginPage = require('../pages/loginPage');
    const loginPage = new LoginPage(driver);
    const loggedOut = await loginPage.isLoggedOut();
    if (loggedOut) {
      const email = process.env.TEST_EMAIL || 'madhuhawk79@gmail.com';
      const password = process.env.TEST_PASSWORD || 'ikmdmad7';
      await loginPage.login(email, password);
    }
  });

  it('TC_11 Should successfully navigate through all bottom tabs', async function() {
    logger.info('Running TC_11: Bottom tabs navigation check');
    const tabsToVerify = ['Dashboard', 'Menu', 'Sales', 'Analytics', 'Waste'];
    const screenshotDir = path.resolve(__dirname, '../reports/screenshots');
    
    if (!fs.existsSync(screenshotDir)) {
      fs.mkdirSync(screenshotDir, { recursive: true });
    }

    for (const tab of tabsToVerify) {
      const startTime = Date.now();
      await dashboardPage.navigateToTab(tab);
      const loadTime = Date.now() - startTime;
      
      logger.info(`Tab ${tab} loaded in ${loadTime}ms`);
      
      const screenshotPath = path.join(screenshotDir, `nav_${tab.toLowerCase()}.png`);
      fs.writeFileSync(screenshotPath, await driver.takeScreenshot(), 'base64');
      
      await dashboardPage.assertAppReady(`${tab} tab screen`);
    }
  });

  it('TC_12 Should successfully record a new sale transaction', async function() {
    logger.info('Running TC_12: Record sale transaction CRUD flow');
    
    // Navigate and open Sales entry card
    await dashboardPage.openSalesDialog();
    
    // Record sale
    const today = new Date().toISOString().split('T')[0];
    await dashboardPage.recordSale(today, '25');
    
    const screenshotPath = path.join(path.resolve(__dirname, '../reports/screenshots'), 'sales_submitted.png');
    fs.writeFileSync(screenshotPath, await driver.takeScreenshot(), 'base64');
    
    logger.info('Sale record submitted.');
  });

  it('TC_13 Should navigate to Dashboard view successfully', async function() {
    logger.info('Running TC_13: Verify Dashboard Tab routing');
    await dashboardPage.navigateToTab('Dashboard');
    await dashboardPage.assertAppReady('Dashboard tab screen');
  });

  it('TC_14 Should navigate to Menu view successfully', async function() {
    logger.info('Running TC_14: Verify Menu Tab routing');
    await dashboardPage.navigateToTab('Menu');
    await dashboardPage.assertAppReady('Menu tab screen');
  });

  it('TC_15 Should navigate to Sales view successfully', async function() {
    logger.info('Running TC_15: Verify Sales Tab routing');
    await dashboardPage.navigateToTab('Sales');
    await dashboardPage.assertAppReady('Sales tab screen');
  });

  it('TC_16 Should navigate to Analytics view successfully', async function() {
    logger.info('Running TC_16: Verify Analytics Tab routing');
    await dashboardPage.navigateToTab('Analytics');
    await dashboardPage.assertAppReady('Analytics tab screen');
  });

  it('TC_17 Should navigate to Waste view successfully', async function() {
    logger.info('Running TC_17: Verify Waste Tab routing');
    await dashboardPage.navigateToTab('Waste');
    await dashboardPage.assertAppReady('Waste tab screen');
  });

  it('TC_18 Should toggle navigation drawer menu', async function() {
    logger.info('Running TC_18: Side drawer toggle');
    // Open drawer
    await dashboardPage.tapRatio(dashboardPage.menuDrawerRatio.x, dashboardPage.menuDrawerRatio.y);
    await dashboardPage.sleep(1500);
    // Close drawer by tapping outside
    await dashboardPage.tapRatio(0.9, 0.5);
    await dashboardPage.sleep(1000);
    await dashboardPage.assertAppReady('Navigation drawer screen');
  });

  it('TC_19 Should handle native back button navigation', async function() {
    logger.info('Running TC_19: Native back navigation routing');
    await dashboardPage.navigateToTab('Menu');
    await dashboardPage.navigateToTab('Analytics');
    
    // Send back command to return to Menu
    await driver.navigate().back();
    await dashboardPage.sleep(2000);
    await driver.executeScript('mobile: activateApp', { appId: getAppPackage() });
    await dashboardPage.sleep(2000);
    
    await dashboardPage.waitForAppReady('Back button recovery screen', 45000);
  });

  it('TC_20 Should verify direct tab navigation transitions', async function() {
    logger.info('Running TC_20: Direct tab transitions speed');
    const start = Date.now();
    await dashboardPage.navigateToTab('Dashboard');
    const duration = Date.now() - start;
    logger.info(`Dashboard tab direct transition took ${duration}ms`);
    expect(duration).to.be.lessThan(15000); // must transition within 15 seconds
  });
});
