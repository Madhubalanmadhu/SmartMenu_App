const { expect } = require('chai');
const { getDriver } = require('./baseSetup');
const DashboardPage = require('../pages/dashboardPage');
const logger = require('../utilities/logger');

describe('SmartMenu E2E Performance Benchmarking Flow', function() {
  this.timeout(120000);

  let driver;
  let dashboardPage;

  before(function() {
    driver = getDriver();
    dashboardPage = new DashboardPage(driver);
  });

  it('TC_30 Should benchmark application session startup latency', async function() {
    logger.info('Running TC_30: Application session initialization latency benchmark');
    // Start timing
    const start = Date.now();
    
    // Trigger terminal relaunch or navigation refresh to simulate reload
    await driver.navigate().refresh().catch(() => {});
    await dashboardPage.sleep(5000);
    
    const loadTime = Date.now() - start;
    logger.info(`Cold startup / refresh simulation completed in ${loadTime}ms`);
    expect(loadTime).to.be.lessThan(25000); // threshold check
  });

  it('TC_31 Should benchmark transition screen load latency for Analytics tab data', async function() {
    logger.info('Running TC_31: Analytics view transition latency benchmark');
    
    const start = Date.now();
    await dashboardPage.navigateToTab('Analytics');
    const duration = Date.now() - start;
    
    logger.info(`Analytics view data render completed in ${duration}ms`);
    expect(duration).to.be.lessThan(15000);
  });

  it('TC_32 Should stress-test system responsiveness under rapid consecutive clicks', async function() {
    logger.info('Running TC_32: Stress-test responsiveness limits');
    const start = Date.now();
    
    // Rapidly switch tabs (Dashboard -> Menu -> Sales -> Waste) with very brief sleep
    await dashboardPage.navigateToTab('Dashboard');
    await dashboardPage.sleep(500);
    await dashboardPage.navigateToTab('Menu');
    await dashboardPage.sleep(500);
    await dashboardPage.navigateToTab('Sales');
    await dashboardPage.sleep(500);
    await dashboardPage.navigateToTab('Waste');
    
    const totalDuration = Date.now() - start;
    logger.info(`Rapid stress navigation switches finished in ${totalDuration}ms`);
    expect(totalDuration).to.be.lessThan(30000);
  });
});
