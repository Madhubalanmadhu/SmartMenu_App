const logger = require('./logger');

class Gestures {
  static async tap(driver, element) {
    logger.debug('Performing tap gesture on element');
    try {
      const elementId = await element.getId();
      await driver.executeScript('mobile: clickGesture', { elementId });
    } catch (error) {
      logger.debug(`UiAutomator2 clickGesture failed: ${error.message}. Falling back to standard actions.`);
      await driver.actions().move({ origin: element }).press().release().perform();
    }
  }

  static async tapAtCoordinates(driver, x, y) {
    logger.debug(`Performing tap gesture at coordinates (${x}, ${y})`);
    try {
      // Primary: Use standard W3C actions to move and click at CSS coordinates in the WebView viewport
      await driver.actions()
        .move({ x: parseInt(x), y: parseInt(y) })
        .press()
        .release()
        .perform();
      logger.debug('W3C Actions tap completed successfully.');
    } catch (error) {
      logger.debug(`W3C actions click failed: ${error.message}. Trying Appium clickGesture scaled by devicePixelRatio.`);
      try {
        const density = await driver.executeScript('return window.devicePixelRatio || 1;').catch(() => 1);
        const physX = Math.round(x * density);
        const physY = Math.round(y * density);
        await driver.executeScript('mobile: clickGesture', { x: physX, y: physY });
      } catch (err2) {
        logger.error(`All coordinate tap attempts failed: ${err2.message}`);
        throw err2;
      }
    }
  }

  static async longPressAtCoordinates(driver, x, y, durationMs = 2000) {
    logger.debug(`Performing long press gesture at coordinates (${x}, ${y})`);
    try {
      await driver.executeScript('mobile: longClickGesture', { x, y, duration: durationMs });
    } catch (error) {
      logger.debug(`UiAutomator2 longClickGesture by coordinates failed: ${error.message}.`);
      throw error;
    }
  }

  static async doubleTap(driver, element) {
    logger.debug('Performing double tap gesture');
    try {
      const elementId = await element.getId();
      await driver.executeScript('mobile: doubleClickGesture', { elementId });
    } catch (error) {
      logger.debug('Falling back to W3C double tap actions');
      const actions = driver.actions();
      await actions.move({ origin: element }).press().release().perform();
      await driver.sleep(100);
      await actions.move({ origin: element }).press().release().perform();
    }
  }

  static async longPress(driver, element, durationMs = 2000) {
    logger.debug(`Performing long press gesture for ${durationMs}ms`);
    try {
      const elementId = await element.getId();
      await driver.executeScript('mobile: longClickGesture', { elementId, duration: durationMs });
    } catch (error) {
      logger.debug('Falling back to W3C long press actions');
      await driver.actions().move({ origin: element }).press().pause(durationMs).release().perform();
    }
  }

  static async swipe(driver, direction, percent = 0.75, speed = 5000) {
    logger.debug(`Performing swipe ${direction} (${percent * 100}%)`);
    try {
      // Swipe on the root window
      await driver.executeScript('mobile: swipeGesture', {
        left: 100,
        top: 100,
        width: 800,
        height: 1200,
        direction,
        percent,
        speed
      });
    } catch (error) {
      logger.error(`Failed to swipe ${direction}: ${error.message}`);
      throw error;
    }
  }

  static async swipeLeft(driver) { return this.swipe(driver, 'left'); }
  static async swipeRight(driver) { return this.swipe(driver, 'right'); }
  static async swipeUp(driver) { return this.swipe(driver, 'up'); }
  static async swipeDown(driver) { return this.swipe(driver, 'down'); }

  static async scrollUntilVisible(driver, elementLocator, maxRetries = 10, direction = 'down') {
    logger.debug(`Scrolling ${direction} until element is visible`);
    for (let i = 0; i < maxRetries; i++) {
      try {
        const elements = await driver.findElements(elementLocator);
        if (elements.length > 0 && await elements[0].isDisplayed()) {
          logger.info('Element found and visible!');
          return elements[0];
        }
      } catch (e) {}

      logger.debug(`Scroll attempt ${i + 1}/${maxRetries}...`);
      try {
        await driver.executeScript('mobile: scrollGesture', {
          left: 100,
          top: 200,
          width: 800,
          height: 1000,
          direction,
          percent: 0.5
        });
      } catch (err) {
        logger.error(`Error during scroll: ${err.message}`);
      }
      await driver.sleep(500);
    }
    throw new Error(`Element could not be found after scrolling ${maxRetries} times`);
  }

  static async dragAndDrop(driver, sourceElement, targetElement) {
    logger.debug('Performing drag and drop gesture');
    try {
      const sourceId = await sourceElement.getId();
      const targetRect = await targetElement.getRect();
      const endX = targetRect.x + (targetRect.width / 2);
      const endY = targetRect.y + (targetRect.height / 2);
      
      await driver.executeScript('mobile: dragGesture', {
        elementId: sourceId,
        endX,
        endY,
        speed: 2500
      });
    } catch (error) {
      logger.error(`Drag and drop failed: ${error.message}`);
      throw error;
    }
  }

  static async pinch(driver, element, percent = 0.5) {
    logger.debug('Performing pinch gesture (zoom out)');
    try {
      const elementId = await element.getId();
      await driver.executeScript('mobile: pinchCloseGesture', {
        elementId,
        percent
      });
    } catch (error) {
      logger.error(`Pinch gesture failed: ${error.message}`);
      throw error;
    }
  }

  static async zoom(driver, element, percent = 0.5) {
    logger.debug('Performing zoom gesture (pinch open)');
    try {
      const elementId = await element.getId();
      await driver.executeScript('mobile: pinchOpenGesture', {
        elementId,
        percent
      });
    } catch (error) {
      logger.error(`Zoom gesture failed: ${error.message}`);
      throw error;
    }
  }
}

module.exports = Gestures;
