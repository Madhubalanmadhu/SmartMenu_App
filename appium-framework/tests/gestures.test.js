const { expect } = require('chai');
const { getDriver } = require('./baseSetup');
const DashboardPage = require('../pages/dashboardPage');
const Gestures = require('../utilities/gestures');
const logger = require('../utilities/logger');

describe('SmartMenu Mobile Gestures Flow', function() {
  this.timeout(120000);

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

  it('TC_27 Should perform scroll down actions on data list views', async function() {
    logger.info('Running TC_27: Vertical scroll gestures check');
    await dashboardPage.navigateToTab('Menu');
    
    // Perform scroll gesture downwards on the screen
    await Gestures.swipeUp(driver); // swipe up scrolls page down
    await dashboardPage.sleep(2000);
    
    await dashboardPage.assertAppReady('Vertical scroll gesture screen');
  });

  it('TC_28 Should swipe horizontally to switch navigation contexts', async function() {
    logger.info('Running TC_28: Horizontal swipe gesture');
    await dashboardPage.navigateToTab('Dashboard');
    
    // Swipe left/right to trigger transitions if configured, or check boundary swipe
    await Gestures.swipeLeft(driver);
    await dashboardPage.sleep(2000);
    await Gestures.swipeRight(driver);
    await dashboardPage.sleep(2000);
    
    await dashboardPage.assertAppReady('Horizontal swipe gesture screen');
  });

  it('TC_29 Should perform a long press gesture on dashboard metrics cards', async function() {
    logger.info('Running TC_29: Long press gesture execution');
    await dashboardPage.navigateToTab('Dashboard');
    
    // Perform long press gesture on dashboard center area (approx x=500, y=500 on 1000x1000 screen)
    const coordinates = await dashboardPage.getCoordinates(0.5, 0.5);
    
    await Gestures.longPressAtCoordinates(driver, coordinates.x, coordinates.y, 2000);
    await dashboardPage.sleep(1500);
    
    await dashboardPage.assertAppReady('Long press gesture screen');
  });
});
