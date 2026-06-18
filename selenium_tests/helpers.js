const { Builder, By, until } = require('selenium-webdriver');
const chrome = require('selenium-webdriver/chrome');
const config = require('./config');

// In-memory test run accumulator
const testRuns = [];
let currentTestRun = null;

/**
 * Initializes a new test run context for Excel reporting
 */
function startTestRun(testName, role) {
  currentTestRun = {
    name: testName,
    role: role,
    status: 'Passed', // Default to passed, will be updated to failed if errors occur
    startTime: Date.now(),
    endTime: null,
    duration: 0,
    steps: [],
    error: null
  };
  testRuns.push(currentTestRun);
  console.log(`\n>>> Starting E2E Test: "${testName}" [Role: ${role}]`);
}

/**
 * Logs a step description inside the current test run context
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
 * Ends the current test run context, calculating durations
 */
function endTestRun(status, error = null) {
  if (currentTestRun) {
    currentTestRun.status = status;
    currentTestRun.endTime = Date.now();
    currentTestRun.duration = parseFloat(((currentTestRun.endTime - currentTestRun.startTime) / 1000).toFixed(2));
    if (error) {
      currentTestRun.error = error.message || String(error);
      logStep(`Test execution failed: ${currentTestRun.error}`, 'Failed');
    } else {
      logStep(`Test completed successfully.`, 'Passed');
    }
  }
  currentTestRun = null;
}

/**
 * Retrieves all accumulated test runs
 */
function getTestRuns() {
  return testRuns;
}

/**
 * Builds the Selenium WebDriver based on configuration
 */
async function buildDriver() {
  const options = new chrome.Options();
  
  if (config.headless) {
    options.addArguments('--headless=new');
  }
  
  options.addArguments('--disable-gpu');
  options.addArguments('--no-sandbox');
  options.addArguments('--disable-dev-shm-usage');
  options.addArguments('--window-size=1280,800');

  const driver = await new Builder()
    .forBrowser(config.browserName)
    .setChromeOptions(options)
    .build();
    
  return driver;
}

/**
 * Custom wrapper helpers with automatic waits, specialized for Flutter Web
 */
class BrowserHelper {
  constructor(driver) {
    this.driver = driver;
    this.timeout = config.defaultTimeout;
  }

  // Navigate to base URL
  async navigate() {
    logStep(`Navigating to Web App URL: ${config.baseUrl}`);
    await this.driver.get(config.baseUrl);
    await this.driver.wait(until.elementLocated(By.tagName('body')), this.timeout);
    // Give Flutter engine time to render
    await this.driver.sleep(3000);
  }

  /**
   * Extremely robust element clicking designed for Flutter Web (HTML & Canvas overlays).
   * It looks for aria-labels, text nodes, buttons, or semantic nodes.
   */
  async clickElement(label, stepDescription = '') {
    // Escape double quotes in label for XPath safety
    const safeLabel = label.replace(/"/g, '\\"');
    
    // Ordered strategies for locating clickables in Flutter Web
    const xpathStrategies = [
      // 1. Exact match on aria-label (preferred in canvaskit)
      `//*[@aria-label="${safeLabel}"]`,
      // 2. Contains match on aria-label
      `//*[contains(@aria-label, "${safeLabel}")]`,
      // 3. Exact text match
      `//*[text()="${safeLabel}"]`,
      // 4. Contains text match
      `//*[contains(text(), "${safeLabel}")]`,
      // 5. Button tag matching
      `//button[contains(text(), "${safeLabel}") or contains(@aria-label, "${safeLabel}")]`
    ];

    let element = null;
    let lastError = null;

    for (const xpath of xpathStrategies) {
      try {
        const locator = By.xpath(xpath);
        // Quick check if element is present & visible
        element = await this.driver.wait(until.elementLocated(locator), 1200);
        await this.driver.wait(until.elementIsVisible(element), 1200);
        break; // Found and visible, break out of search
      } catch (err) {
        lastError = err;
      }
    }

    if (!element) {
      throw new Error(`Could not find clickable element for "${label}". Search attempts failed: ${lastError.message}`);
    }

    // Scroll element into viewport
    await this.driver.executeScript('arguments[0].scrollIntoView({block: "center"});', element);
    await this.driver.sleep(200);
    
    try {
      await element.click();
    } catch (clickErr) {
      // Fallback: click via Javascript if overlay blocks standard click
      await this.driver.executeScript('arguments[0].click();', element);
    }

    logStep(stepDescription || `Clicked "${label}"`);
    await this.driver.sleep(1000); // Wait for transition
  }

  /**
   * Robust typing into form fields. Locates elements via placeholder, labels, 
   * aria-labels, or adjacent text labels.
   */
  async typeInField(label, text, stepDescription = '') {
    const safeLabel = label.replace(/"/g, '\\"');

    const xpathStrategies = [
      // 1. Direct input with matching placeholder or aria-label
      `//input[contains(@placeholder, "${safeLabel}") or contains(@aria-label, "${safeLabel}")]`,
      // 2. Input inside an element that has the aria-label
      `//*[@aria-label[contains(., "${safeLabel}")]]//input`,
      // 3. Input following a text label (classic form pattern)
      `//*[contains(text(), "${safeLabel}") or contains(@aria-label, "${safeLabel}")]/following::input[1]`,
      // 4. Any text input inside a parent that has the label text
      `//*[contains(text(), "${safeLabel}")]/ancestor::div[1]//input`
    ];

    let element = null;
    let lastError = null;

    for (const xpath of xpathStrategies) {
      try {
        const locator = By.xpath(xpath);
        element = await this.driver.wait(until.elementLocated(locator), 1200);
        await this.driver.wait(until.elementIsVisible(element), 1200);
        break; // Found!
      } catch (err) {
        lastError = err;
      }
    }

    if (!element) {
      throw new Error(`Could not locate input field for label "${label}". Search failed: ${lastError.message}`);
    }

    await this.driver.executeScript('arguments[0].scrollIntoView({block: "center"});', element);
    await this.driver.sleep(200);
    
    // Clear and input text
    await element.clear();
    // Some browsers/renderers might need a click before typing
    await element.click().catch(() => {});
    await element.sendKeys(text);
    
    logStep(stepDescription || `Typed "${text}" in "${label}" field`);
    await this.driver.sleep(300);
  }

  /**
   * Custom dropdown selection supporting standard list options.
   */
  async selectDropdownValue(label, valueText, stepDescription = '') {
    logStep(`Opening dropdown for "${label}"`);
    // Click the dropdown field
    await this.clickElement(label);
    await this.driver.sleep(800); // Let option overlay load
    // Click the value option
    await this.clickElement(valueText, stepDescription || `Selected dropdown value: "${valueText}"`);
  }

  /**
   * Resilient text assertion supporting both aria-labels and text nodes.
   */
  async waitForText(text, customTimeout = this.timeout) {
    const safeText = text.replace(/"/g, '\\"');
    const xpath = `//*[contains(text(), "${safeText}") or contains(@aria-label, "${safeText}")]`;
    
    try {
      await this.driver.wait(until.elementLocated(By.xpath(xpath)), customTimeout);
      logStep(`Verified page element containing text/label: "${text}"`);
    } catch (err) {
      throw new Error(`Timeout waiting for text/label "${text}" to appear on page.`);
    }
  }

  /**
   * Back navigation helper (finds typical Flutter web back buttons).
   */
  async goBack(stepDescription = 'Click back button') {
    const xpath = `//button[contains(@aria-label, "Back") or contains(@aria-label, "back") or contains(@class, "back")] | //*[contains(@aria-label, "Back") or contains(@aria-label, "back")]`;
    try {
      const element = await this.driver.wait(until.elementLocated(By.xpath(xpath)), 2000);
      await this.driver.executeScript('arguments[0].click();', element);
      logStep(stepDescription);
      await this.driver.sleep(1000);
    } catch (_) {
      // Fallback: browser back
      await this.driver.navigate().back();
      logStep(`${stepDescription} (fallback to browser history back)`);
      await this.driver.sleep(1000);
    }
  }

  async sleep(ms) {
    await this.driver.sleep(ms);
  }

  // -------------------------------------------------------------------------
  // Convenience aliases used by test_e2e.js
  // -------------------------------------------------------------------------

  /**
   * Click an element located by its visible text / aria-label.
   * Alias around clickElement for readability in tests.
   */
  async clickByText(text, stepDescription = '') {
    await this.clickElement(text, stepDescription);
  }

  /**
   * Click an element located by an explicit Selenium `By` locator.
   */
  async click(locator, stepDescription = '') {
    const element = await this.driver.wait(until.elementLocated(locator), this.timeout);
    await this.driver.wait(until.elementIsVisible(element), this.timeout).catch(() => {});
    await this.driver.executeScript('arguments[0].scrollIntoView({block: "center"});', element);
    await this.driver.sleep(200);
    try {
      await element.click();
    } catch (_) {
      await this.driver.executeScript('arguments[0].click();', element);
    }
    logStep(stepDescription || 'Clicked element by locator');
    await this.driver.sleep(800);
  }

  /**
   * Type into an input located by an explicit Selenium `By` locator.
   */
  async type(locator, text, stepDescription = '') {
    const element = await this.driver.wait(until.elementLocated(locator), this.timeout);
    await this.driver.wait(until.elementIsVisible(element), this.timeout).catch(() => {});
    await this.driver.executeScript('arguments[0].scrollIntoView({block: "center"});', element);
    await this.driver.sleep(200);
    await element.clear().catch(() => {});
    await element.click().catch(() => {});
    await element.sendKeys(text);
    logStep(stepDescription || `Typed "${text}" into element`);
    await this.driver.sleep(300);
  }
}

module.exports = {
  startTestRun,
  logStep,
  endTestRun,
  getTestRuns,
  buildDriver,
  BrowserHelper
};
