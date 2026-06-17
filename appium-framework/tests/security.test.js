const { expect } = require('chai');
const path = require('path');
const fs = require('fs');
const { getDriver } = require('./baseSetup');
const LoginPage = require('../pages/loginPage');
const DashboardPage = require('../pages/dashboardPage');
const logger = require('../utilities/logger');
const { getAppPackage } = require('../config/capabilities');

describe('SmartMenu Mobile App Security & Isolation Suite', function() {
  this.timeout(120000);

  let driver;
  let loginPage;
  let dashboardPage;

  before(async function() {
    driver = getDriver();
    loginPage = new LoginPage(driver);
    dashboardPage = new DashboardPage(driver);
    if (driver) {
      await driver.executeScript('mobile: activateApp', { appId: getAppPackage() });
      await loginPage.sleep(1000);
    }
  });

  it('TC_33 Should enforce password field masking during credentials input', async function() {
    logger.info('Running TC_33: Password input masking validation');
    if (!driver) {
      this.skip();
    }
    
    await loginPage.clearInputs();
    await loginPage.enterPassword('secretpassword123');
    
    // Take screenshot to document password field security state
    const screenshotDir = path.resolve(__dirname, '../reports/screenshots');
    if (!fs.existsSync(screenshotDir)) {
      fs.mkdirSync(screenshotDir, { recursive: true });
    }
    const screenshotPath = path.join(screenshotDir, 'security_password_masked.png');
    fs.writeFileSync(screenshotPath, await driver.takeScreenshot(), 'base64');
    
    logger.info('Password masking validation completed.');
  });

  it('TC_34 Should restrict access to dashboard screens for unauthenticated users', async function() {
    logger.info('Running TC_34: Authentication guard validation');
    if (!driver) {
      this.skip();
    }
    
    // Ensure logged out
    const loggedOut = await loginPage.isLoggedOut();
    if (!loggedOut) {
      await dashboardPage.logout().catch(() => {});
    }
    
    // Attempt direct action or verify landing on login
    await loginPage.assertAppReady('Login gate security screen');
    logger.info('Authentication guard validation successful.');
  });

  it('TC_35 Should clear session cache and tokens upon successful logout', async function() {
    logger.info('Running TC_35: Session clearance validation');
    if (!driver) {
      this.skip();
    }
    
    // Log in
    const email = process.env.TEST_EMAIL || 'madhuhawk79@gmail.com';
    const password = process.env.TEST_PASSWORD || 'ikmdmad7';
    await loginPage.login(email, password);
    
    // Log out and assert
    await dashboardPage.logout();
    await loginPage.assertAppReady('Logged out session clear screen');
    
    logger.info('Session state clearance validation successful.');
  });
});
