require('dotenv').config();
const path = require('path');

const APPIUM_SERVER = process.env.APPIUM_SERVER || 'http://127.0.0.1:4723';
const BASE_URL = process.env.BASE_URL || 'http://127.0.0.1:50379';

// Default APK path points to the real Flutter Android app.
const DEFAULT_APK_PATH = path.resolve(__dirname, '../../flutter_app/build/app/outputs/flutter-apk/app-debug.apk');
const DEFAULT_APP_PACKAGE = 'com.example.flutter_app';
const DEFAULT_APP_ACTIVITY = '.MainActivity';

function getCapabilities() {
  const useApk = process.env.USE_APK === 'true' || !!process.env.APK_PATH;
  const apkPath = process.env.APK_PATH ? path.resolve(process.env.APK_PATH) : DEFAULT_APK_PATH;

  const caps = {
    browserName: '',
    platformName: 'Android',
    'appium:automationName': 'UiAutomator2',
    'appium:deviceName': process.env.DEVICE_NAME || 'Android Emulator',
    'appium:noReset': process.env.NO_RESET !== 'false',
    'appium:newCommandTimeout': parseInt(process.env.NEW_COMMAND_TIMEOUT || '120'),
    'appium:ignoreHiddenApiPolicyError': true,
    'appium:noSign': true,
    'appium:uiautomator2ServerLaunchTimeout': 90000
  };

  if (useApk) {
    caps['appium:app'] = apkPath;
  } else {
    caps['appium:appPackage'] = process.env.APP_PACKAGE || DEFAULT_APP_PACKAGE;
    caps['appium:appActivity'] = process.env.APP_ACTIVITY || DEFAULT_APP_ACTIVITY;
  }

  // Allow passing additional specific capabilities via environment variables
  if (process.env.ANDROID_VERSION) {
    caps['appium:platformVersion'] = process.env.ANDROID_VERSION;
  }

  if (process.env.UDID) {
    caps['appium:udid'] = process.env.UDID;
  }

  return caps;
}

module.exports = {
  APPIUM_SERVER,
  BASE_URL,
  DEFAULT_APP_PACKAGE,
  DEFAULT_APP_ACTIVITY,
  getCapabilities,
  getAppPackage: () => process.env.APP_PACKAGE || DEFAULT_APP_PACKAGE
};
