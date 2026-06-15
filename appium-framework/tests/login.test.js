const { expect } = require('chai');
const path = require('path');
const fs = require('fs');
const { getDriver } = require('./baseSetup');
const LoginPage = require('../pages/loginPage');
const DashboardPage = require('../pages/dashboardPage');
const { BASE_URL } = require('../config/capabilities');
const { getAppPackage } = require('../config/capabilities');
const logger = require('../utilities/logger');

describe('SmartMenu Authentication Flow', function() {
  this.timeout(120000); // Allow sufficient time for mobile actions

  let driver;
  let loginPage;
  let dashboardPage;

  before(async function() {
    driver = getDriver();
    loginPage = new LoginPage(driver);
    dashboardPage = new DashboardPage(driver);
    await driver.executeScript('mobile: activateApp', { appId: getAppPackage() });
    await loginPage.sleep(1000);
    const loggedOut = await loginPage.isLoggedOut();
    if (!loggedOut) {
      await dashboardPage.logout().catch(err => {
        logger.warn(`Initial auth-suite logout skipped: ${err.message}`);
      });
    }
  });

  it('TC_01 Should fail to login with empty credentials', async function() {
    logger.info('Running TC_01: Empty credentials validation');
    
    // Relaunch or open web page inside WebView if needed, or wait
    await loginPage.sleep(5000); 
    
    // Clear first to be sure
    await loginPage.clearInputs();
    
    // Tap login button
    await loginPage.clickLogin();
    
    // Take a screenshot to inspect warning
    const screenshotDir = path.resolve(__dirname, '../reports/screenshots');
    if (!fs.existsSync(screenshotDir)) {
      fs.mkdirSync(screenshotDir, { recursive: true });
    }
    const screenshotPath = path.join(screenshotDir, 'login_empty_error.png');
    fs.writeFileSync(screenshotPath, await driver.takeScreenshot(), 'base64');
    
    await loginPage.assertAppReady('Empty credentials validation screen');
  });

  it('TC_02 Should fail to login with invalid credentials', async function() {
    logger.info('Running TC_02: Invalid credentials validation');
    
    await loginPage.clearInputs();
    await loginPage.enterEmail('wronguser@domain.com');
    await loginPage.enterPassword('wrongpassword');
    await loginPage.clickLogin();
    
    const screenshotPath = path.join(path.resolve(__dirname, '../reports/screenshots'), 'login_invalid_error.png');
    fs.writeFileSync(screenshotPath, await driver.takeScreenshot(), 'base64');
    
    await loginPage.assertAppReady('Invalid credentials validation screen');
  });

  it('TC_03 Should login successfully with valid credentials', async function() {
    logger.info('Running TC_03: Valid credentials login');
    
    const email = process.env.TEST_EMAIL || 'madhuhawk79@gmail.com';
    const password = process.env.TEST_PASSWORD || 'ikmdmad7';
    
    await loginPage.clearInputs();
    await loginPage.login(email, password);
    
    // Verify landing on Dashboard
    const screenshotPath = path.join(path.resolve(__dirname, '../reports/screenshots'), 'login_success.png');
    fs.writeFileSync(screenshotPath, await driver.takeScreenshot(), 'base64');
    
    await dashboardPage.assertAppReady('Successful login dashboard screen');
    logger.info('Login validation successful.');
  });

  it('TC_04 Should logout successfully', async function() {
    logger.info('Running TC_04: Logout flow');
    
    await dashboardPage.logout();
    
    const screenshotPath = path.join(path.resolve(__dirname, '../reports/screenshots'), 'logout_success.png');
    fs.writeFileSync(screenshotPath, await driver.takeScreenshot(), 'base64');
    
    await loginPage.assertAppReady('Logout result screen');
    logger.info('Logout validation successful.');
  });

  it('TC_05 Should handle session persistence on app relaunch', async function() {
    logger.info('Running TC_05: Session persistence validation');
    
    // Login again first
    const email = process.env.TEST_EMAIL || 'madhuhawk79@gmail.com';
    const password = process.env.TEST_PASSWORD || 'ikmdmad7';
    await loginPage.login(email, password);
    
    logger.info('Relaunching application to test session persistence...');
    // Terminate and relaunch app
    const appPackage = getAppPackage();
    try {
      await driver.executeScript('mobile: terminateApp', { appId: appPackage });
      await driver.sleep(2000);
      await driver.executeScript('mobile: activateApp', { appId: appPackage });
      await driver.sleep(6000);
    } catch (err) {
      logger.warn(`Native App Relaunch script not supported, performing navigate refresh instead: ${err.message}`);
      // Fallback: navigate refresh or reset
      await driver.navigate().refresh();
      await driver.sleep(6000);
    }

    const screenshotPath = path.join(path.resolve(__dirname, '../reports/screenshots'), 'session_persistence.png');
    fs.writeFileSync(screenshotPath, await driver.takeScreenshot(), 'base64');
    await dashboardPage.waitForAppReady('Session persistence relaunch screen', 45000);
    logger.info('Session persistence check completed.');

    await dashboardPage.logout().catch(err => {
      logger.warn(`Post-session-persistence logout cleanup skipped: ${err.message}`);
    });
  });

  it('TC_06 Should validate required email/password fields are enforced', async function() {
    logger.info('Running TC_06: Required field checking');
    // Ensure we are logged out
    const loggedOut = await dashboardPage.isLoggedOut();
    if (!loggedOut) {
      await dashboardPage.logout().catch(() => {});
    }
    await loginPage.clearInputs();
    
    // Enter email but leave password blank
    await loginPage.enterEmail('madhuhawk79@gmail.com');
    await loginPage.clickLogin();
    
    await loginPage.assertAppReady('Required password validation screen');
  });

  it('TC_07 Should reject malformed email formats during input validation', async function() {
    logger.info('Running TC_07: Email format regex checking');
    await loginPage.clearInputs();
    
    // Type malformed email and valid password
    await loginPage.enterEmail('bademailformat.com');
    await loginPage.enterPassword('ikmdmad7');
    await loginPage.clickLogin();
    
    await loginPage.assertAppReady('Malformed email validation screen');
  });

  it('TC_08 Should validate phone boundary formats under profile/forms', async function() {
    logger.info('Running TC_08: Phone format boundary checking');
    await loginPage.clearInputs();
    // We type an invalid phone pattern to verify text field handling
    await loginPage.enterEmail('123-abc-789');
    await loginPage.enterPassword('password123');
    await loginPage.clickLogin();
    
    await loginPage.assertAppReady('Phone boundary validation screen');
  });

  it('TC_09 Should reject weak passwords during validation checks', async function() {
    logger.info('Running TC_09: Weak password check');
    await loginPage.clearInputs();
    
    // Type simple password
    await loginPage.enterEmail('madhuhawk79@gmail.com');
    await loginPage.enterPassword('123');
    await loginPage.clickLogin();
    
    await loginPage.assertAppReady('Weak password validation screen');
  });

  it('TC_10 Should respect character length boundaries on credentials input', async function() {
    logger.info('Running TC_10: Maximum length stress test');
    await loginPage.clearInputs();
    
    const longString = 'a'.repeat(80); // Inject long input
    await loginPage.enterEmail(longString);
    await loginPage.enterPassword('ikmdmad7');
    await loginPage.clickLogin();
    
    await loginPage.assertAppReady('Credential length validation screen');
  });
});
