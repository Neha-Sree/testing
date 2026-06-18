const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const { buildDriver, AppHelper, startTestRun, endTestRun, logStep } = require('./helpers');

/** Collects all visible TextViews from the current screen as a single string. */
async function captureScreenText(driver) {
  try {
    const els = await driver.$$('android=new UiSelector().className("android.widget.TextView")');
    const texts = [];
    for (const el of els) {
      const t = await el.getText().catch(() => '');
      if (t.trim()) texts.push(t.trim());
    }
    return texts.join(' | ');
  } catch (_) {
    return '(could not read screen)';
  }
}

/** Saves a PNG screenshot to appium_tests/screenshots/. */
async function takeScreenshot(driver, label) {
  try {
    const dir = path.join(__dirname, 'screenshots');
    if (!fs.existsSync(dir)) fs.mkdirSync(dir);
    const base64 = await driver.takeScreenshot();
    const outPath = path.join(dir, `${label}_${Date.now()}.png`);
    fs.writeFileSync(outPath, Buffer.from(base64, 'base64'));
    logStep(`Screenshot saved: ${path.basename(outPath)}`, 'Passed');
  } catch (_) {}
}

/**
 * Re-apply the adb reverse tunnel so the phone can reach the PC backend via
 * localhost:8000. Appium's APK install/re-launch can disrupt the previous tunnel.
 */
function applyAdbTunnel() {
  try {
    const udid = process.env.DEVICE_UDID || 'RZCW20R70SD';
    const adb = `"C:\\Users\\Neha\\AppData\\Local\\Android\\Sdk\\platform-tools\\adb.exe"`;
    execSync(`${adb} -s ${udid} reverse tcp:8000 tcp:8000`, { stdio: 'pipe' });
    logStep('adb reverse tunnel re-applied (phone → PC backend:8000)', 'Passed');
  } catch (e) {
    logStep('adb reverse re-apply warning: ' + e.message, 'Warning');
  }
}

describe('Life Nest Mobile E2E Tests (Appium / Android)', function () {
  // E2E flows are slow on real devices/emulators.
  this.timeout(240000);

  let driver;
  let app;

  before(async function () {
    driver = await buildDriver();
    app = new AppHelper(driver);
    // Re-apply tunnel after Appium completes APK install and session startup.
    // The tunnel is USB-level and survives APK reinstall; re-applying ensures
    // it is active before the first API call.
    applyAdbTunnel();
    await app.sleep(500);
  });

  after(async function () {
    if (driver) {
      await driver.deleteSession();
    }
  });

  // -------------------------------------------------------------------------
  // 1. MOTHER: register -> onboarding profile -> dashboard features
  // -------------------------------------------------------------------------
  it('should register a new Mother, complete onboarding, and interact with the Dashboard', async function () {
    const testName = 'Mother Role - Registration, Onboarding and Dashboard Features';
    startTestRun(testName, 'Mother');

    try {
      await app.waitForAppReady();

      // Entry screen -> account creation.
      await app.tap('Create new account', 'Tap "Create new account"');
      await app.waitForText('Please select your role to continue');

      // Choose Mother role.
      await app.tap('Mother', 'Select "Mother" role card');
      await app.waitForText('Welcome, Mother!');

      // Fill the account creation form (3 fields: Name, Phone, Password).
      const suffix = Math.floor(Math.random() * 90000 + 10000);
      const motherName = `Jane Doe ${suffix}`;
      await app.typeInField('Full Name', motherName, { fieldIndex: 0, stepDescription: `Enter Full Name: ${motherName}` });
      await app.typeInField('Phone Number', '9876543210', { fieldIndex: 1, stepDescription: 'Enter Phone Number: 9876543210' });
      await app.typeInField('Password', 'pass123', { fieldIndex: 2, stepDescription: 'Enter Password: *******' });

      // Press the keyboard Done key — Flutter's TextInputAction.done on the
      // password field triggers onFieldSubmitted which submits the form.
      // This avoids needing to scroll to the "Create Account" button hidden under the keyboard.
      await driver.pressKeyCode(66);
      logStep('Pressed keyboard Done key to submit registration form');
      await app.sleep(1000);
      applyAdbTunnel();
      await app.sleep(8000);

      // Snapshot visible screen text to aid diagnosis.
      const screenText1 = await captureScreenText(driver);
      logStep(`Screen after Create Account (8s): ${screenText1}`, 'Passed');

      if (screenText1.includes('reach backend') || screenText1.includes('Cannot reach')) {
        throw new Error('Backend unreachable from phone. Check adb reverse tunnel.');
      }

      // Onboarding profile.
      await app.waitForText("Let's build your profile, Mom!");

      await app.typeInField('Age', '27', { fieldIndex: 0, stepDescription: 'Input Age: 27' });
      await driver.pressKeyCode(66); // dismiss numeric keyboard after Age
      await app.sleep(400);

      await app.typeInField('Weight', '62', { fieldIndex: 1, stepDescription: 'Input Weight: 62 kg' });
      await driver.pressKeyCode(66); // dismiss keyboard so Weeks Pregnant becomes visible
      await app.sleep(600);

      // Blood group dropdown (best effort).
      try {
        await app.selectDropdownValue('Blood Group', 'AB+', 'Select blood group AB+');
      } catch (e) {
        logStep('Blood Group dropdown skipped, default O+ retained: ' + e.message, 'Warning');
      }

      await app.typeInField('Weeks Pregnant', '14', { fieldIndex: 2, stepDescription: 'Input Weeks Pregnant: 14' });
      await driver.pressKeyCode(66); // dismiss keyboard before date picker
      await app.sleep(600);

      // Due date picker (best effort).
      try {
        await app.tap('Select your due date', 'Open due date picker');
        await app.sleep(800);
        await app.tap('OK', 'Confirm pre-selected due date');
      } catch (e) {
        logStep('Due date picker skipped: ' + e.message, 'Warning');
      }

      // Flutter only exposes visible EditTexts to the accessibility tree.
      // After scrolling down, the field indices restart from 0 for the new viewport.
      // Scroll 1: brings Phone(0), Address(1), Emergency(2) into view.
      await driver.pressKeyCode(66); // ensure keyboard closed before scroll
      await app.sleep(400);
      await app.scrollDown(0.45);
      await app.sleep(600);

      // After scroll: Phone=0, Address=1, Emergency=2 in the current viewport.
      // Type each field in sequence; the keyboard may open/close between fields.
      await app.typeInField('Phone Number', '9876543210', { fieldIndex: 0, stepDescription: 'Input Phone Number: 9876543210' });
      await driver.pressKeyCode(66);
      await app.sleep(400);
      await app.typeInField('Address', '123 Motherhood Blvd', { fieldIndex: 1, stepDescription: 'Input Address' });
      await driver.pressKeyCode(66);
      await app.sleep(400);
      await app.typeInField('Emergency Contact', 'John Doe 9999888877', { fieldIndex: 2, stepDescription: 'Input Emergency Contact' });

      // Scroll down to reveal allergy chips and the Complete Setup button.
      await driver.pressKeyCode(66); // dismiss keyboard before final scroll
      await app.sleep(400);
      await app.scrollDown(0.45);
      await app.sleep(500);

      // Allergy chip (best effort).
      try {
        await app.tap('Dairy', 'Select "Dairy" allergy chip');
      } catch (e) {
        logStep('Dairy allergy chip skipped: ' + e.message, 'Warning');
      }

      // Scroll one more time if Complete Setup is still below the fold.
      await app.scrollDown(0.3);
      await app.sleep(400);
      await app.tap('Complete Setup', 'Tap "Complete Setup" to save Mother profile');
      await app.sleep(4000);

      // Dashboard verification (mom dashboard greets "Hi, <name>" and has a Tools section).
      await app.waitForText('Tools');
      logStep('Successfully reached Mother Dashboard');

      // Hydration Tracker feature (best effort).
      try {
        await app.tap('Hydration Tracker', 'Open Hydration Tracker');
        await app.waitForText('Hydration Tracker');
        await app.tap('+250ml', 'Log 250ml water intake');
        await app.goBack('Return to dashboard from Hydration Tracker');
      } catch (e) {
        logStep('Hydration Tracker feature skipped: ' + e.message, 'Warning');
      }

      // Kick Counter feature (best effort).
      try {
        await app.tap('Kick Counter', 'Open Kick Counter');
        await app.waitForText('Baby Kick Counter');
        await app.tap('Record Kick', 'Record a baby kick');
        await app.tap('Save Session', 'Save kick session');
        await app.goBack('Return to dashboard from Kick Counter');
      } catch (e) {
        logStep('Kick Counter feature skipped: ' + e.message, 'Warning');
      }

      endTestRun('Passed');
    } catch (err) {
      await takeScreenshot(driver, 'fail_mother');
      endTestRun('Failed', err);
      throw err;
    }
  });

  // -------------------------------------------------------------------------
  // 2. DOCTOR: register -> dashboard
  // -------------------------------------------------------------------------
  it('should register a new Doctor and verify Doctor Dashboard access', async function () {
    const testName = 'Doctor Role - Registration and Dashboard Verification';
    startTestRun(testName, 'Doctor');

    try {
      // Force a clean restart: terminate, clear app data, then relaunch.
      const pkg = require('./config').capabilities['appium:appPackage'];
      await driver.terminateApp(pkg).catch(() => {});
      // Clear app data so the app starts fresh from the splash screen.
      try {
        const { execSync: exec } = require('child_process');
        const adb = `"C:\\Users\\Neha\\AppData\\Local\\Android\\Sdk\\platform-tools\\adb.exe"`;
        exec(`${adb} -s ${process.env.DEVICE_UDID || 'RZCW20R70SD'} shell pm clear ${pkg}`, { stdio: 'pipe' });
        logStep('App data cleared for clean launch', 'Passed');
      } catch (e) {
        logStep('App data clear warning: ' + e.message, 'Warning');
      }
      await driver.activateApp(pkg);
      await app.waitForAppReady();

      await app.tap('Create new account', 'Tap "Create new account"');
      await app.waitForText('Please select your role to continue');

      await app.tap('Doctor', 'Select "Doctor" role');
      await app.waitForText('Welcome, Doctor!');

      const suffix = Math.floor(Math.random() * 90000 + 10000);
      const doctorName = `Dr. House ${suffix}`;
      await app.typeInField('Full Name', doctorName, { fieldIndex: 0, stepDescription: `Enter Full Name: ${doctorName}` });
      await app.typeInField('Phone Number', '8888888888', { fieldIndex: 1, stepDescription: 'Enter Phone Number: 8888888888' });
      await app.typeInField('Password', 'docpass123', { fieldIndex: 2, stepDescription: 'Enter Password: *******' });

      await driver.pressKeyCode(66);
      logStep('Pressed keyboard Done key to submit registration form');
      applyAdbTunnel();
      await app.sleep(8000);

      const screenText2 = await captureScreenText(driver);
      logStep(`Screen after Create Account (8s): ${screenText2}`, 'Passed');

      // Doctor shell uses bottom-nav tabs: Overview / Mothers / Today / Risk / SOS.
      await app.waitForText('Mothers');
      logStep(`Verified Doctor dashboard access for: ${doctorName}`);

      // Navigate doctor bottom-nav tabs (best effort).
      try {
        await app.tap('Mothers', 'Open Mothers tab');
        await app.tap('Today', 'Open Today tab');
        await app.tap('Overview', 'Return to Overview tab');
      } catch (e) {
        logStep('Doctor tab navigation skipped: ' + e.message, 'Warning');
      }

      endTestRun('Passed');
    } catch (err) {
      await takeScreenshot(driver, 'fail_doctor');
      endTestRun('Failed', err);
      throw err;
    }
  });

  // -------------------------------------------------------------------------
  // 3. HEALTH WORKER: register -> dashboard
  // -------------------------------------------------------------------------
  it('should register a new Health Worker and verify Health Worker Dashboard access', async function () {
    const testName = 'Health Worker Role - Registration and Dashboard Verification';
    startTestRun(testName, 'Health Worker');

    try {
      const pkg3 = require('./config').capabilities['appium:appPackage'];
      await driver.terminateApp(pkg3).catch(() => {});
      try {
        const { execSync: exec } = require('child_process');
        const adb = `"C:\\Users\\Neha\\AppData\\Local\\Android\\Sdk\\platform-tools\\adb.exe"`;
        exec(`${adb} -s ${process.env.DEVICE_UDID || 'RZCW20R70SD'} shell pm clear ${pkg3}`, { stdio: 'pipe' });
        logStep('App data cleared for clean launch', 'Passed');
      } catch (e) {
        logStep('App data clear warning: ' + e.message, 'Warning');
      }
      await driver.activateApp(pkg3);
      await app.waitForAppReady();

      await app.tap('Create new account', 'Tap "Create new account"');
      await app.waitForText('Please select your role to continue');

      await app.tap('Health Worker', 'Select "Health Worker" role');
      await app.waitForText('Welcome, Health Worker!');

      const suffix = Math.floor(Math.random() * 90000 + 10000);
      const workerName = `Nurse Brenda ${suffix}`;
      await app.typeInField('Full Name', workerName, { fieldIndex: 0, stepDescription: `Enter Full Name: ${workerName}` });
      await app.typeInField('Phone Number', '7777777777', { fieldIndex: 1, stepDescription: 'Enter Phone Number: 7777777777' });
      await app.typeInField('Password', 'workerpass123', { fieldIndex: 2, stepDescription: 'Enter Password: *******' });

      await driver.pressKeyCode(66);
      logStep('Pressed keyboard Done key to submit registration form');
      applyAdbTunnel();
      await app.sleep(8000);

      const screenText3 = await captureScreenText(driver);
      logStep(`Screen after Create Account (8s): ${screenText3}`, 'Passed');

      // Health worker dashboard shows a hero banner + an "Assign mother" action.
      await app.waitForText('Assign mother');
      logStep(`Verified Health Worker Dashboard access for: ${workerName}`);

      if (await app.isPresent(workerName)) {
        logStep('Verified worker name is shown on the dashboard banner');
      } else {
        logStep('Worker name banner not found', 'Warning');
      }

      endTestRun('Passed');
    } catch (err) {
      await takeScreenshot(driver, 'fail_health_worker');
      endTestRun('Failed', err);
      throw err;
    }
  });
});
