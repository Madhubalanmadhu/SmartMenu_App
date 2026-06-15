const logger = require('../utilities/logger');
const Gestures = require('../utilities/gestures');
const { By } = require('selenium-webdriver');
const { getAppPackage } = require('../config/capabilities');
const { captureAndValidate } = require('../utilities/screenshotValidator');

class BasePage {
  constructor(driver) {
    this.driver = driver;
    this.viewportSize = null;
  }

  async getViewportSize() {
    if (this.viewportSize) return this.viewportSize;

    let size = { width: 1000, height: 1000 };
    try {
      size = await this.driver.executeScript(`
        return { width: window.innerWidth, height: window.innerHeight };
      `);
      logger.debug(`Retrieved viewport size via window: ${JSON.stringify(size)}`);
    } catch (e) {
      try {
        const winSize = await this.driver.manage().window().getSize();
        size = { width: winSize.width, height: winSize.height };
        logger.debug(`Retrieved viewport size via window manager: ${JSON.stringify(size)}`);
      } catch (e2) {
        logger.warn(`Could not get viewport size. Defaulting to 1000x1000. Error: ${e2.message}`);
      }
    }
    this.viewportSize = size;
    return size;
  }

  async getCoordinates(xRatio, yRatio) {
    const size = await this.getViewportSize();
    const x = Math.floor(size.width * xRatio);
    const y = Math.floor(size.height * yRatio);
    logger.debug(`Mapped ratios (${xRatio}, ${yRatio}) to coordinates (${x}, ${y})`);
    return { x, y };
  }

  async tapRatio(xRatio, yRatio) {
    const { x, y } = await this.getCoordinates(xRatio, yRatio);
    await Gestures.tapAtCoordinates(this.driver, x, y);
    await this.driver.sleep(1000);
  }

  async sendKeysToRatio(xRatio, yRatio, text) {
    logger.info(`Entering text into area at ratio (${xRatio}, ${yRatio})`);
    await this.tapRatio(xRatio, yRatio);
    await this.driver.actions().sendKeys(text).perform();
    await this.driver.sleep(1000);
  }

  async clearField(xRatio, yRatio) {
    logger.debug(`Clearing input at ratio (${xRatio}, ${yRatio})`);
    await this.tapRatio(xRatio, yRatio);
    await this.driver.actions().sendKeys('\uE003'.repeat(80)).perform();
    await this.driver.sleep(500);
  }

  async isLoggedOut() {
    try {
      const url = await this.driver.getCurrentUrl();
      logger.debug(`Current URL: ${url}`);
      if (url.includes('/login') || !url.includes('/home')) {
        return true;
      }
    } catch (e) {
      logger.debug(`URL based login-state check skipped: ${e.message}`);
    }

    try {
      const source = await this.driver.getPageSource();
      return /login|email|password/i.test(source) && !/dashboard|analytics|waste/i.test(source);
    } catch (e) {
      logger.debug(`Page source login-state check skipped: ${e.message}`);
      return false;
    }
  }

  async assertAppReady(label = 'App screen') {
    const expectedPackage = getAppPackage();
    const source = await this.driver.getPageSource();
    if (!source.includes(`package="${expectedPackage}"`) && !source.includes(expectedPackage)) {
      throw new Error(`${label} is not showing expected app package ${expectedPackage}`);
    }

    const { analysis } = await captureAndValidate(this.driver, null, label);
    logger.info(
      `${label} screenshot OK: ${analysis.width}x${analysis.height}, colors=${analysis.uniqueColorCount}, brightnessStdDev=${analysis.brightnessStandardDeviation.toFixed(2)}`
    );
    return source;
  }

  async waitForAppReady(label = 'App screen', timeoutMs = 30000, intervalMs = 2000) {
    const deadline = Date.now() + timeoutMs;
    let lastError;

    while (Date.now() < deadline) {
      try {
        return await this.assertAppReady(label);
      } catch (error) {
        lastError = error;
        logger.warn(`${label} not ready yet: ${error.message}`);
        await this.driver.sleep(intervalMs);
      }
    }

    throw lastError || new Error(`${label} did not become ready within ${timeoutMs}ms`);
  }

  async sleep(ms) {
    await this.driver.sleep(ms);
  }
}

module.exports = BasePage;
