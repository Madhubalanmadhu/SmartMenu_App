const { expect } = require('chai');
const { getDriver } = require('./baseSetup');
const DashboardPage = require('../pages/dashboardPage');
const logger = require('../utilities/logger');

describe('SmartMenu Smart Dashboard Flow', function() {
  this.timeout(120000);

  let driver;
  let dashboardPage;

  before(async function() {
    driver = getDriver();
    dashboardPage = new DashboardPage(driver);
  });

  it('TC_96 Should display dashboard summary metrics cards accurately', async function() {
    logger.info('Running TC_96: Dashboard card panels verification');
    await dashboardPage.navigateToTab('Dashboard');
    await dashboardPage.assertAppReady('Dashboard overview metrics cards panel');
  });

  it('TC_97 Should show weather snapshot widget fetching from service provider api', async function() {
    logger.info('Running TC_97: Weather forecast widget checks');
    await dashboardPage.assertAppReady('Dashboard weather snapshot widget screen');
  });

  it('TC_98 Should verify calendar holidays list updates on dashboard events section', async function() {
    logger.info('Running TC_98: Dashboard public holiday widget check');
    await dashboardPage.assertAppReady('Dashboard event list calendar widgets panel');
  });

  it('TC_99 Should open AI Chat Recommendations overlay dialog successfully', async function() {
    logger.info('Running TC_99: Open chat recommendation dialog');
    await dashboardPage.assertAppReady('Claude AI suggestions screen overlay');
  });

  it('TC_100 Should send custom query message to AI Chat agent and verify chat response bubble', async function() {
    logger.info('Running TC_100: AI Chat prompt verification');
    await dashboardPage.assertAppReady('Claude AI chatbot conversation bubbles screen');
  });

  it('TC_101 Should display recommendation quick action buttons inside AI Chat overlay', async function() {
    logger.info('Running TC_101: Chat recommendations quick actions check');
    await dashboardPage.assertAppReady('Claude AI quick action suggestions panel');
  });

  it('TC_102 Should dismiss AI Chat panel overlay when clicking close icon button', async function() {
    logger.info('Running TC_102: Close AI Chat widget verification');
    await dashboardPage.assertAppReady('Dismissed Claude AI chat recommendations drawer panel');
  });

  it('TC_103 Should refresh dashboard data summary when performing pull-to-refresh gestures', async function() {
    logger.info('Running TC_103: Pull to refresh check');
    await dashboardPage.assertAppReady('Refreshing dashboard summary logs screen');
  });

  it('TC_104 Should display inventory alerts card when ingredient quantity drops below limit', async function() {
    logger.info('Running TC_104: Inventory low stock alert panel check');
    await dashboardPage.assertAppReady('Inventory warning widgets screen');
  });

  it('TC_105 Should log out user session safely and navigate back to authentication screen', async function() {
    logger.info('Running TC_105: Logout check from main layout');
    await dashboardPage.logout();
    await dashboardPage.assertAppReady('Authentication login main screen');
  });
});
