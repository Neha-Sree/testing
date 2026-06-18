const { remote } = require('webdriverio');
const config = require('./config');

// ---------------------------------------------------------------------------
// In-memory test run accumulator (shared with the Excel report generator).
// ---------------------------------------------------------------------------
const testRuns = [];
let currentTestRun = null;

/**
 * Initializes a new test run context for Excel reporting.
 */
function startTestRun(testName, role) {
  currentTestRun = {
    name: testName,
    role: role,
    status: 'Passed',
    startTime: Date.now(),
    endTime: null,
    duration: 0,
    steps: [],
    error: null
  };
  testRuns.push(currentTestRun);
  console.log(`\n>>> Starting Appium E2E Test: "${testName}" [Role: ${role}]`);
}

/**
 * Logs a step description inside the current test run context.
 */
function logStep(stepDescription, status = 'Passed') {
  if (currentTestRun) {
    currentTestRun.steps.push({
      timestamp: new Date().toISOString().split('T')[1].substring(0, 8),
      description: stepDescription,
      status: status
    });
  }
  console.log(`   [${status}] ${stepDescription}`);
}

/**
 * Ends the current test run context, calculating durations.
 */
function endTestRun(status, error = null) {
  if (currentTestRun) {
    currentTestRun.status = status;
    currentTestRun.endTime = Date.now();
    currentTestRun.duration = parseFloat(
      ((currentTestRun.endTime - currentTestRun.startTime) / 1000).toFixed(2)
    );
    if (error) {
      currentTestRun.error = error.message || String(error);
      logStep(`Test execution failed: ${currentTestRun.error}`, 'Failed');
    } else {
      logStep('Test completed successfully.', 'Passed');
    }
  }
  currentTestRun = null;
}

function getTestRuns() {
  return testRuns;
}

/**
 * Builds the Appium (WebdriverIO) driver from configuration.
 */
async function buildDriver() {
  const caps = { ...config.capabilities };
  // Strip undefined keys so WebdriverIO doesn't forward null capabilities.
  Object.keys(caps).forEach((k) => caps[k] === undefined && delete caps[k]);

  const driver = await remote({
    hostname: config.appium.hostname,
    port: config.appium.port,
    path: config.appium.path,
    logLevel: config.appium.logLevel,
    capabilities: caps
  });

  return driver;
}

// ---------------------------------------------------------------------------
// AppHelper: resilient wrappers specialized for a Flutter Android app driven
// through UiAutomator2. Flutter exposes its semantics tree to Android
// accessibility, so labels surface as `text` and/or `content-desc`.
// ---------------------------------------------------------------------------
class AppHelper {
  constructor(driver) {
    this.driver = driver;
    this.timeout = config.defaultTimeout;
  }

  async sleep(ms) {
    await this.driver.pause(ms);
  }

  /**
   * Waits for the splash screen to finish and the first real screen to appear.
   */
  async waitForAppReady() {
    logStep(`Launching Life Nest app and waiting for splash (${config.splashWaitMs}ms)`);
    await this.sleep(config.splashWaitMs);
    try {
      await this.driver.activateApp('com.example.my_app');
      await this.sleep(1000);
    } catch (e) {
      logStep('Warning: Failed to activate app: ' + e.message, 'Warning');
    }
  }

  /**
   * Builds an ordered list of UiAutomator2 selectors for a label. We try
   * accessibility-id (content-desc) first, then text, then "contains" variants.
   */
  _candidateSelectors(label) {
    const escaped = label.replace(/"/g, '\\"');
    return [
      `~${label}`, // accessibility id == exact content-desc
      `android=new UiSelector().description("${escaped}")`,
      `android=new UiSelector().text("${escaped}")`,
      `android=new UiSelector().descriptionContains("${escaped}")`,
      `android=new UiSelector().textContains("${escaped}")`
    ];
  }

  /**
   * Finds the first matching, displayed element for a label using the strategy
   * cascade. Returns the WebdriverIO element or null.
   */
  async findByLabel(label, perStrategyTimeout = 1500) {
    for (const selector of this._candidateSelectors(label)) {
      try {
        const el = await this.driver.$(selector);
        await el.waitForExist({ timeout: perStrategyTimeout });
        if (await el.isExisting()) {
          return el;
        }
      } catch (_) {
        // Try the next strategy.
      }
    }
    return null;
  }

  /**
   * Robust tap on an element identified by visible text or content-desc.
   */
  async tap(label, stepDescription = '') {
    const el = await this.findByLabel(label, Math.max(2000, this.timeout / 4));
    if (!el) {
      throw new Error(`Could not find tappable element for "${label}".`);
    }
    try {
      await el.click();
    } catch (clickErr) {
      // Fallback: tap by element center coordinates.
      const loc = await el.getLocation();
      const size = await el.getSize();
      await this.driver
        .action('pointer')
        .move({ x: Math.round(loc.x + size.width / 2), y: Math.round(loc.y + size.height / 2) })
        .down()
        .up()
        .perform();
    }
    logStep(stepDescription || `Tapped "${label}"`);
    await this.sleep(1200);
  }

  /**
   * Types into a text field. Strategy:
   *   1. Try to resolve a field whose content-desc/text matches the label.
   *   2. Fall back to the Nth EditText on screen (fieldIndex, 0-based).
   */
  async typeInField(label, text, { fieldIndex = null, stepDescription = '' } = {}) {
    let el = await this.findByLabel(label, 1500);

    // If the found element is a static label (TextView, not an EditText), try to
    // find the actual input field by content-desc or fall back to fieldIndex.
    if (el) {
      const cls = await el.getAttribute('class').catch(() => '');
      if (cls !== 'android.widget.EditText') {
        const escaped = label.replace(/"/g, '\\"');
        const nearField = await this.driver
          .$(`android=new UiSelector().className("android.widget.EditText").descriptionContains("${escaped}")`)
          .catch(() => null);
        if (nearField && (await nearField.isExisting().catch(() => false))) {
          el = nearField;
        } else {
          // The matched element is a label, not an input — discard it so we can
          // fall through to the fieldIndex branch below.
          el = null;
        }
      }
    }

    if ((!el || !(await el.isExisting().catch(() => false))) && fieldIndex !== null) {
      const fields = await this.driver.$$('android=new UiSelector().className("android.widget.EditText")');
      if (fields[fieldIndex]) {
        el = fields[fieldIndex];
      }
    }

    if (!el) {
      throw new Error(`Could not locate input field for label "${label}".`);
    }

    await el.click();
    await this.sleep(400);
    try {
      await el.clearValue();
    } catch (_) {
      // Some Flutter fields don't support clearValue; ignore.
    }
    await el.setValue(text);
    logStep(stepDescription || `Entered "${text}" into "${label}" field`);
    await this.sleep(400);
  }

  /**
   * Selects a value from an open-on-tap dropdown / list.
   */
  async selectDropdownValue(label, valueText, stepDescription = '') {
    logStep(`Opening dropdown for "${label}"`);
    await this.tap(label);
    await this.sleep(800);
    await this.tap(valueText, stepDescription || `Selected dropdown value: "${valueText}"`);
  }

  /**
   * Asserts that an element containing the given text/label is present.
   */
  async waitForText(text, customTimeout = this.timeout) {
    const el = await this.findByLabel(text, customTimeout);
    if (!el) {
      throw new Error(`Timeout waiting for text/label "${text}" to appear on screen.`);
    }
    logStep(`Verified screen element containing text/label: "${text}"`);
  }

  /**
   * Returns true if a label is present (no throw). Useful for optional steps.
   */
  async isPresent(label, customTimeout = 2500) {
    const el = await this.findByLabel(label, customTimeout);
    return !!el;
  }

  /**
   * Dismisses the soft keyboard by performing a quick tap-and-release at the
   * scroll view's content area (below the AppBar, above the keyboard).
   * Avoids pressing BACK (which navigates away) and avoids the AppBar
   * (which can trigger scroll-to-top on Flutter).
   */
  async dismissKeyboardSafely() {
    try {
      const { width, height } = await this.driver.getWindowSize();
      // Tap in the middle-top quadrant of the screen — inside the scroll area
      // but above any keyboard region. For a typical 900dp screen the keyboard
      // starts at ~570dp (63%), so y=160 is safe.
      await this.driver
        .action('pointer')
        .move({ x: Math.round(width / 2), y: 160 })
        .down()
        .up()
        .perform();
      await this.sleep(450);
    } catch (_) { /* ignore */ }
  }

  /**
   * Scrolls the screen downward by swiping from the bottom-center to top-center.
   * Call this when fields are below the visible fold.
   */
  async scrollDown(fraction = 0.5) {
    const { width, height } = await this.driver.getWindowSize();
    const x = Math.round(width / 2);
    const startY = Math.round(height * 0.75);
    const endY = Math.round(height * (0.75 - fraction));

    await this.driver
      .action('pointer')
      .move({ x, y: startY })
      .down()
      .pause(100)
      .move({ x, y: endY, duration: 600 })
      .up()
      .perform();

    await this.sleep(700);
  }

  /**
   * Navigates back (Flutter AppBar back button, then device back as fallback).
   */
  async goBack(stepDescription = 'Navigate back') {
    const backBtn = await this.findByLabel('Back', 1500);
    if (backBtn) {
      await backBtn.click();
      logStep(stepDescription);
    } else {
      await this.driver.back();
      logStep(`${stepDescription} (device back button)`);
    }
    await this.sleep(1000);
  }
}

module.exports = {
  startTestRun,
  logStep,
  endTestRun,
  getTestRuns,
  buildDriver,
  AppHelper
};
