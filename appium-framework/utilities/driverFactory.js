const { Builder } = require('selenium-webdriver');
const { execSync } = require('child_process');
const { APPIUM_SERVER, getCapabilities } = require('../config/capabilities');
const logger = require('./logger');

class DriverFactory {
  static detectConnectedDevice() {
    try {
      logger.info('Scanning for connected Android devices/emulators via adb...');
      const stdout = execSync('adb devices', { encoding: 'utf8' });
      const lines = stdout.trim().split('\n');
      const devices = [];
      
      for (let i = 1; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line && !line.startsWith('*') && line.includes('device')) {
          const parts = line.split(/\s+/);
          if (parts[0]) {
            devices.push(parts[0]);
          }
        }
      }

      if (devices.length > 0) {
        logger.info(`Detected devices: ${JSON.stringify(devices)}. Using: ${devices[0]}`);
        return devices[0];
      }
      logger.warn('No active adb devices or emulators detected. Falling back to default capabilities.');
    } catch (error) {
      logger.warn(`Could not run adb check: ${error.message}. Falling back to default capabilities.`);
    }
    return null;
  }

  static async createDriver() {
    const caps = getCapabilities();
    
    if (process.env.UDID) {
      caps['appium:udid'] = process.env.UDID;
      caps['appium:deviceName'] = process.env.DEVICE_NAME || process.env.UDID;
      logger.info(`Using UDID from environment: ${process.env.UDID}`);
    } else {
      // Automatically detect and configure UDID if we find a connected device
      const detectedUdid = this.detectConnectedDevice();
      if (detectedUdid) {
      caps['appium:udid'] = detectedUdid;
      // Also update deviceName to use the detected UDID/name
      caps['appium:deviceName'] = detectedUdid;
      }
    }

    logger.info(`Initializing Appium session at: ${APPIUM_SERVER}`);
    logger.info(`Desired Capabilities: ${JSON.stringify(caps, null, 2)}`);

    try {
      const driver = await new Builder()
        .usingServer(APPIUM_SERVER)
        .forBrowser('')
        .withCapabilities(caps)
        .build();
      
      logger.info('Appium session established successfully.');
      return driver;
    } catch (error) {
      logger.error(`Failed to initialize Appium session: ${error.message}`);
      throw error;
    }
  }
}

module.exports = DriverFactory;
