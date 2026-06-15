const { By, until } = require('selenium-webdriver');
const logger = require('./logger');

class Waits {
  static async waitForElementLocatable(driver, locator, timeout = 15000) {
    logger.debug(`Waiting for element to be locatable: ${JSON.stringify(locator)}`);
    try {
      return await driver.wait(until.elementLocated(locator), timeout);
    } catch (error) {
      logger.error(`Element not locatable: ${JSON.stringify(locator)} - ${error.message}`);
      throw error;
    }
  }

  static async waitForElementVisible(driver, locator, timeout = 15000) {
    logger.debug(`Waiting for element to be visible: ${JSON.stringify(locator)}`);
    try {
      const element = await this.waitForElementLocatable(driver, locator, timeout);
      await driver.wait(until.elementIsVisible(element), timeout);
      return element;
    } catch (error) {
      logger.error(`Element not visible: ${JSON.stringify(locator)} - ${error.message}`);
      throw error;
    }
  }

  static async waitForElementClickable(driver, locator, timeout = 15000) {
    logger.debug(`Waiting for element to be clickable: ${JSON.stringify(locator)}`);
    try {
      const element = await this.waitForElementVisible(driver, locator, timeout);
      await driver.wait(until.elementIsEnabled(element), timeout);
      return element;
    } catch (error) {
      logger.error(`Element not clickable: ${JSON.stringify(locator)} - ${error.message}`);
      throw error;
    }
  }

  static async click(driver, locator, timeout = 15000) {
    logger.debug(`Clicking element: ${JSON.stringify(locator)}`);
    const element = await this.waitForElementClickable(driver, locator, timeout);
    await element.click();
  }

  static async sendKeys(driver, locator, text, timeout = 15000) {
    logger.debug(`Sending keys to element: ${JSON.stringify(locator)}`);
    const element = await this.waitForElementVisible(driver, locator, timeout);
    await element.clear();
    await element.sendKeys(text);
  }

  static async getText(driver, locator, timeout = 15000) {
    logger.debug(`Getting text from element: ${JSON.stringify(locator)}`);
    const element = await this.waitForElementVisible(driver, locator, timeout);
    return await element.getText();
  }

  static async isDisplayed(driver, locator, timeout = 5000) {
    try {
      const element = await this.waitForElementVisible(driver, locator, timeout);
      return await element.isDisplayed();
    } catch (error) {
      return false;
    }
  }

  static async hideKeyboard(driver) {
    logger.debug('Attempting to hide software keyboard...');
    try {
      await driver.hideKeyboard();
    } catch (error) {
      logger.debug(`Hide keyboard skipped (or not active): ${error.message}`);
    }
  }

  static async acceptAlert(driver) {
    logger.debug('Accepting alert dialog...');
    try {
      await driver.switchTo().alert().accept();
    } catch (error) {
      logger.error(`Failed to accept alert: ${error.message}`);
    }
  }

  static async dismissAlert(driver) {
    logger.debug('Dismissing alert dialog...');
    try {
      await driver.switchTo().alert().dismiss();
    } catch (error) {
      logger.error(`Failed to dismiss alert: ${error.message}`);
    }
  }

  static async getAlertText(driver) {
    logger.debug('Getting alert text...');
    try {
      return await driver.switchTo().alert().getText();
    } catch (error) {
      logger.error(`Failed to get alert text: ${error.message}`);
      return '';
    }
  }
}

module.exports = Waits;
