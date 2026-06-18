// Appium / Android E2E configuration for the Life Nest mobile application.
// Every value can be overridden through environment variables so the suite can
// run on different machines / devices / CI without editing this file.

const path = require('path');

module.exports = {
  // ---- Appium server connection ----
  appium: {
    hostname: process.env.APPIUM_HOST || '127.0.0.1',
    port: parseInt(process.env.APPIUM_PORT || '4723', 10),
    // Appium 2.x serves the W3C endpoints at the root path.
    path: process.env.APPIUM_PATH || '/',
    logLevel: process.env.APPIUM_LOG_LEVEL || 'error'
  },

  // ---- Android device / capabilities ----
  capabilities: {
    platformName: 'Android',
    'appium:automationName': 'UiAutomator2',
    // Leave deviceName generic; UiAutomator2 attaches to the first online device.
    'appium:deviceName': process.env.DEVICE_NAME || 'Android Device',
    // Optional explicit device id (use `adb devices` to find it).
    'appium:udid': process.env.DEVICE_UDID || undefined,
    'appium:platformVersion': process.env.PLATFORM_VERSION || undefined,

    // Install + launch the freshly built APK. If APP_PATH is not provided we
    // fall back to launching an already-installed build via package/activity.
    'appium:app': process.env.APP_PATH
      ? path.resolve(process.env.APP_PATH)
      : path.resolve(
          __dirname,
          '..',
          'build',
          'app',
          'outputs',
          'flutter-apk',
          'app-debug.apk'
        ),
    'appium:appPackage': process.env.APP_PACKAGE || 'com.example.my_app',
    'appium:appActivity':
      process.env.APP_ACTIVITY || 'com.example.my_app.MainActivity',

    // Robustness / timing tweaks for Flutter rendered UIs.
    'appium:autoGrantPermissions': true,
    'appium:newCommandTimeout': 300,
    'appium:adbExecTimeout': 60000,
    'appium:uiautomator2ServerInstallTimeout': 60000,
    'appium:disableWindowAnimation': true,
    // Flutter exposes its widget tree to Android accessibility, which is how
    // UiAutomator2 resolves text / content-desc selectors.
    'appium:ensureWebviewsHavePages': true,
    // Force APK reinstall this run (LAN IP rebuild), then switch to noReset for speed.
    'appium:noReset': process.env.NO_RESET === 'true' || false,
    'appium:fullReset': process.env.FULL_RESET === 'true' || false
  },

  // Default element wait timeout (ms).
  defaultTimeout: parseInt(process.env.TIMEOUT || '15000', 10),

  // Splash screen runs for 3s before the entry screen appears.
  splashWaitMs: parseInt(process.env.SPLASH_WAIT || '4500', 10),

  // Output path for the generated Excel report.
  reportPath: process.env.REPORT_PATH || path.join(__dirname, 'reports', 'app_e2e_report.xlsx')
};
