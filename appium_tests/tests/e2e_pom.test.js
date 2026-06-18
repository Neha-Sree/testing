const { execSync } = require('child_process');
const path = require('path');
const { buildDriver, AppHelper, startTestRun, endTestRun, logStep } = require('../helpers');
const config = require('../config');
const { captureScreenshot } = require('../utils/screenshot');
const { log } = require('../utils/logger');
const EntryPage = require('../pages/EntryPage');
const AccountCreationPage = require('../pages/AccountCreationPage');
const MotherOnboardingPage = require('../pages/MotherOnboardingPage');
const MotherDashboardPage = require('../pages/MotherDashboardPage');
const DoctorDashboardPage = require('../pages/DoctorDashboardPage');
const HealthWorkerDashboardPage = require('../pages/HealthWorkerDashboardPage');

function suffix() {
  return Math.floor(Math.random() * 90000 + 10000);
}

function applyAdbReverse() {
  try {
    const udid = process.env.DEVICE_UDID;
    const target = udid ? ` -s ${udid}` : '';
    execSync(`adb${target} reverse tcp:8000 tcp:8000`, { stdio: 'pipe' });
    logStep('ADB reverse tunnel applied for backend access');
  } catch (error) {
    logStep(`ADB reverse tunnel warning: ${error.message}`, 'Warning');
  }
}

async function resetApp(driver) {
  const packageName = config.capabilities['appium:appPackage'];
  await driver.terminateApp(packageName).catch(() => {});
  try {
    const udid = process.env.DEVICE_UDID;
    const target = udid ? ` -s ${udid}` : '';
    execSync(`adb${target} shell pm clear ${packageName}`, { stdio: 'pipe' });
    logStep('Application data cleared for clean E2E journey');
  } catch (error) {
    logStep(`Application reset warning: ${error.message}`, 'Warning');
  }
  await driver.activateApp(packageName);
}

describe('Life Nest Android E2E - POM Appium Suite', function () {
  this.timeout(300000);

  let driver;
  let app;

  before(async function () {
    log('Starting Life Nest POM Appium E2E suite');
    driver = await buildDriver();
    app = new AppHelper(driver);
    applyAdbReverse();
  });

  after(async function () {
    if (driver) {
      await driver.deleteSession();
    }
    log('Finished Life Nest POM Appium E2E suite');
  });

  it('APP-E2E-001 Mother registration, onboarding, dashboard, and tracker features', async function () {
    startTestRun('APP-E2E-001 Mother registration, onboarding, dashboard, and tracker features', 'Mother');
    try {
      await resetApp(driver);
      const entry = new EntryPage(driver, app);
      const account = new AccountCreationPage(driver, app);
      const onboarding = new MotherOnboardingPage(driver, app);
      const dashboard = new MotherDashboardPage(driver, app);

      await entry.openAccountCreation();
      await entry.selectRole('Mother');
      await account.createAccount({
        fullName: `Jane Doe ${suffix()}`,
        phone: '9876543210',
        password: 'pass123'
      });
      applyAdbReverse();
      await app.sleep(8000);
      await onboarding.completeProfile();
      await dashboard.verifyLoaded();
      await dashboard.exerciseDashboardFeatures();
      endTestRun('Passed');
    } catch (error) {
      const screenshotPath = await captureScreenshot(driver, 'mother_e2e_failure');
      logStep(`Failure screenshot: ${path.basename(screenshotPath)}`, 'Failed');
      endTestRun('Failed', error);
      throw error;
    }
  });

  it('APP-E2E-002 Doctor registration and dashboard navigation', async function () {
    startTestRun('APP-E2E-002 Doctor registration and dashboard navigation', 'Doctor');
    try {
      await resetApp(driver);
      const entry = new EntryPage(driver, app);
      const account = new AccountCreationPage(driver, app);
      const dashboard = new DoctorDashboardPage(driver, app);

      await entry.openAccountCreation();
      await entry.selectRole('Doctor');
      await account.createAccount({
        fullName: `Dr. House ${suffix()}`,
        phone: '8888888888',
        password: 'docpass123'
      });
      applyAdbReverse();
      await app.sleep(8000);
      await dashboard.verifyLoaded();
      await dashboard.verifyNavigation();
      endTestRun('Passed');
    } catch (error) {
      const screenshotPath = await captureScreenshot(driver, 'doctor_e2e_failure');
      logStep(`Failure screenshot: ${path.basename(screenshotPath)}`, 'Failed');
      endTestRun('Failed', error);
      throw error;
    }
  });

  it('APP-E2E-003 Health Worker registration and dashboard actions', async function () {
    startTestRun('APP-E2E-003 Health Worker registration and dashboard actions', 'Health Worker');
    try {
      await resetApp(driver);
      const entry = new EntryPage(driver, app);
      const account = new AccountCreationPage(driver, app);
      const dashboard = new HealthWorkerDashboardPage(driver, app);

      await entry.openAccountCreation();
      await entry.selectRole('Health Worker');
      await account.createAccount({
        fullName: `Nurse Brenda ${suffix()}`,
        phone: '7777777777',
        password: 'workerpass123'
      });
      applyAdbReverse();
      await app.sleep(8000);
      await dashboard.verifyLoaded();
      await dashboard.verifyCoreActions();
      endTestRun('Passed');
    } catch (error) {
      const screenshotPath = await captureScreenshot(driver, 'health_worker_e2e_failure');
      logStep(`Failure screenshot: ${path.basename(screenshotPath)}`, 'Failed');
      endTestRun('Failed', error);
      throw error;
    }
  });
});
