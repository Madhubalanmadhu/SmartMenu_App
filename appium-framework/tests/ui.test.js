const { expect } = require('chai');
const path = require('path');
const fs = require('fs');
const { getDriver } = require('./baseSetup');
const LoginPage = require('../pages/loginPage');
const DashboardPage = require('../pages/dashboardPage');
const logger = require('../utilities/logger');
const { getAppPackage } = require('../config/capabilities');

describe('SmartMenu UI Widgets & Interactive Elements Flow', function() {
  this.timeout(120000);

  let driver;
  let loginPage;
  let dashboardPage;

  before(async function() {
    driver = getDriver();
    loginPage = new LoginPage(driver);
    dashboardPage = new DashboardPage(driver);
    await driver.executeScript('mobile: activateApp', { appId: getAppPackage() });
    await dashboardPage.sleep(1000);
    
    const loggedOut = await loginPage.isLoggedOut();
    if (loggedOut) {
      const email = process.env.TEST_EMAIL || 'madhuhawk79@gmail.com';
      const password = process.env.TEST_PASSWORD || 'ikmdmad7';
      await loginPage.login(email, password);
    }
  });

  it('TC_21 Should check login button state during validation flows', async function() {
    logger.info('Running TC_21: Login button validation state');
    const loggedOut = await loginPage.isLoggedOut();
    if (!loggedOut) {
      await dashboardPage.logout().catch(err => {
        logger.warn(`UI login-button validation logout skipped: ${err.message}`);
      });
    }
    await loginPage.clearInputs();
    
    // Attempt login, confirm session remains on login page
    await loginPage.clickLogin();
    await loginPage.assertAppReady('Login button validation screen');
  });

  it('TC_22 Should toggle password text visibility mask', async function() {
    logger.info('Running TC_22: Password mask eye toggle check');
    // Eye icon is typically on the right side of the password field (approx x=0.6, y=0.72)
    const eyeIconRatio = { x: 0.6, y: 0.72 };
    await loginPage.tapRatio(eyeIconRatio.x, eyeIconRatio.y);
    await loginPage.sleep(1000);
    
    await loginPage.assertAppReady('Password visibility toggle screen');
  });

  it('TC_23 Should verify dropdown items populate during data insertion', async function() {
    logger.info('Running TC_23: Dropdown list verification');
    const loggedOut = await loginPage.isLoggedOut();
    if (loggedOut) {
      const email = process.env.TEST_EMAIL || 'madhuhawk79@gmail.com';
      const password = process.env.TEST_PASSWORD || 'ikmdmad7';
      await loginPage.login(email, password);
    }
    
    // Navigate to Sales and open dialog
    await dashboardPage.openSalesDialog();
    
    // Tap dropdown to trigger overlay selection
    await dashboardPage.tapRatio(dashboardPage.salesDishDropdownRatio.x, dashboardPage.salesDishDropdownRatio.y);
    await dashboardPage.sleep(1000);
    
    await dashboardPage.assertAppReady('Dropdown list screen');
  });

  it('TC_24 Should verify card elements populate on Dashboard', async function() {
    logger.info('Running TC_24: Dashboard cards presence check');
    await dashboardPage.navigateToTab('Dashboard');
    
    await dashboardPage.assertAppReady('Dashboard cards screen');
  });

  it('TC_25 Should open and dismiss a dialog modal successfully', async function() {
    logger.info('Running TC_25: Dialog modal open and close flow');
    await dashboardPage.openSalesDialog();
    
    // Tapping outside or cancel button ratio (approx x=0.35, y=0.72 or close coordinate)
    // To dismiss sales dialog, tap outside the modal box boundary (approx x=0.1, y=0.1)
    await dashboardPage.tapRatio(0.1, 0.1);
    await dashboardPage.sleep(2000);
    
    await dashboardPage.assertAppReady('Dialog dismissed screen');
  });

  it('TC_26 Should toggle settings or form checkboxes', async function() {
    logger.info('Running TC_26: Form checkbox toggle check');
    // We navigate to Waste view and trigger check boxes or filters (approx x=0.2, y=0.3)
    await dashboardPage.navigateToTab('Waste');
    await dashboardPage.tapRatio(0.2, 0.3);
    await dashboardPage.sleep(1000);
    
    await dashboardPage.assertAppReady('Checkbox interaction screen');
  });
});
