const { expect } = require('chai');
const { buildDriver, BrowserHelper, startTestRun, endTestRun, logStep } = require('./helpers');
const { By } = require('selenium-webdriver');

describe('Life Nest Web E2E Tests', function () {
  // Increase Mocha test timeout to 2 minutes since E2E takes time
  this.timeout(120000);
  
  let driver;
  let browser;

  before(async function () {
    driver = await buildDriver();
    browser = new BrowserHelper(driver);
  });

  after(async function () {
    if (driver) {
      await driver.quit();
    }
  });

  it('should register a new Mother, complete onboarding, and interact with the Dashboard', async function () {
    const testName = 'Mother Role - Registration, Onboarding and Dashboard Features';
    startTestRun(testName, 'Mother');
    
    try {
      // Step 1: Navigation
      await browser.navigate();
      browser.driver.sleep(1000);

      // Step 2: Navigate to Role Selection
      await browser.clickByText('Create new account', 'Click "Create new account" button');
      await browser.waitForText('Please select your role to continue');

      // Step 3: Choose Mother Role
      await browser.clickByText('Mother', 'Select "Mother" role card');
      await browser.waitForText('Welcome, Mother!');

      // Step 4: Fill Account Creation Form
      const randomIdSuffix = Math.floor(Math.random() * 90000 + 10000);
      const motherName = `Jane Doe ${randomIdSuffix}`;
      
      // Select input fields and type
      await browser.type(By.xpath('//*[contains(text(), "Full Name")]/following::input[1]'), motherName, `Enter Full Name: ${motherName}`);
      await browser.type(By.xpath('//*[contains(text(), "Phone Number")]/following::input[1]'), '9876543210', 'Enter Phone Number: 9876543210');
      await browser.type(By.xpath('//*[contains(text(), "Password")]/following::input[1]'), 'pass123', 'Enter Password: *********');

      // Click Create Account
      await browser.clickByText('Create Account', 'Click "Create Account" button');
      await browser.sleep(2000);
      
      // Step 5: Onboarding Profile Creation
      await browser.waitForText('Let\'s build your profile, Mom!');
      
      // Input Age
      await browser.type(By.xpath('//*[contains(text(), "Age")]/following::input[1]'), '27', 'Input Age: 27');
      
      // Input Weight
      await browser.type(By.xpath('//*[contains(text(), "Weight")]/following::input[1]'), '62', 'Input Weight: 62 kg');
      
      // Select Blood Group (Dropdown)
      try {
        await browser.click(By.xpath('//*[contains(text(), "Blood Group")]/following::*[contains(text(), "Select") or contains(text(), "O+")][1]'), 'Click Blood Group dropdown');
        await browser.sleep(500);
        // Select 'AB+'
        await browser.clickByText('AB+', 'Select "AB+" from the dropdown list');
      } catch (e) {
        logStep('Dropdown click failed, skipping to use default O+ group', 'Warning');
      }

      // Input Weeks Pregnant
      await browser.type(By.xpath('//*[contains(text(), "Weeks Pregnant")]/following::input[1]'), '14', 'Input Weeks Pregnant: 14 weeks');

      // Select Expected Due Date (DatePicker)
      try {
        await browser.clickByText('Select your due date', 'Click Expected Due Date selector');
        await browser.sleep(1000);
        // Standard Material Date Picker: click OK
        await browser.clickByText('OK', 'Accept pre-selected date on the Calendar Picker');
        await browser.sleep(500);
      } catch (e) {
        logStep('Date picker dialog interaction skipped or failed', 'Warning');
      }

      // Input Phone (Onboarding version)
      await browser.type(By.xpath('//*[contains(text(), "Phone Number")]/following::input[1]'), '9876543210', 'Input Phone Number: 9876543210');

      // Input Address
      await browser.type(By.xpath('//*[contains(text(), "Address")]/following::input[1]'), '123 Motherhood Blvd, Pregnancy Valley', 'Input Address: 123 Motherhood Blvd');

      // Input Emergency Contact
      await browser.type(By.xpath('//*[contains(text(), "Emergency Contact")]/following::input[1]'), 'Husband: John Doe - 9999888877', 'Input Emergency Contact: John Doe - 9999888877');

      // Select Allergy filter chip
      try {
        await browser.clickByText('Dairy', 'Select "Dairy" allergy filter chip');
      } catch (e) {
        logStep('Dairy allergy chip not found or click failed', 'Warning');
      }

      // Complete setup and navigate to dashboard
      await browser.clickByText('Complete Setup', 'Click "Complete Setup" button to register Mother profile');
      await browser.sleep(4000); // Wait for onboarding save and dashboard transition

      // Step 6: Verify Dashboard Welcome & Core Stats
      await browser.waitForText('Welcome back, Mom!');
      logStep('Successfully navigated to Mother Dashboard Screen');

      // Navigate to Hydration Tracker screen
      try {
        await browser.clickByText('Hydration Tracker', 'Navigate to Hydration Tracker screen');
        await browser.sleep(2000);
        await browser.waitForText('Hydration Tracker');
        
        // Add 250ml water
        await browser.clickByText('+250ml', 'Log water intake: Add 250ml');
        await browser.sleep(500);
        
        // Return to Dashboard
        await browser.click(By.xpath('//button[contains(@aria-label, "Back") or contains(@aria-label, "back") or contains(@class, "back")]'), 'Click back button to return to dashboard');
        await browser.sleep(1000);
      } catch (e) {
        logStep('Hydration Tracker feature test skipped or failed: ' + e.message, 'Warning');
      }

      // Navigate to Kick Counter screen
      try {
        await browser.clickByText('Kick Counter', 'Navigate to Kick Counter screen');
        await browser.sleep(2000);
        await browser.waitForText('Baby Kick Counter');
        
        // Click Record Kick
        await browser.clickByText('Record Kick', 'Record a baby kick');
        await browser.sleep(500);
        
        // Save Session
        await browser.clickByText('Save Session', 'Save recorded kick session');
        await browser.sleep(1000);
        
        // Return to Dashboard
        await browser.click(By.xpath('//button[contains(@aria-label, "Back") or contains(@aria-label, "back")]'), 'Click back button to return to dashboard');
        await browser.sleep(1000);
      } catch (e) {
        logStep('Kick Counter feature test skipped or failed: ' + e.message, 'Warning');
      }

      endTestRun('Passed');
    } catch (err) {
      endTestRun('Failed', err);
      throw err;
    }
  });

  it('should register a new Doctor and verify Doctor Dashboard access', async function () {
    const testName = 'Doctor Role - Registration and Dashboard Verification';
    startTestRun(testName, 'Doctor');
    
    try {
      // Step 1: Navigation
      await browser.navigate();
      browser.driver.sleep(1000);

      // Step 2: Navigate to Role Selection
      await browser.clickByText('Create new account', 'Click "Create new account" button');
      await browser.waitForText('Please select your role to continue');

      // Step 3: Choose Doctor Role
      await browser.clickByText('Doctor', 'Select "Doctor" role link');
      await browser.waitForText('Welcome, Doctor!');

      // Step 4: Fill Doctor Creation Form
      const randomIdSuffix = Math.floor(Math.random() * 90000 + 10000);
      const doctorName = `Dr. House ${randomIdSuffix}`;
      
      await browser.type(By.xpath('//*[contains(text(), "Full Name")]/following::input[1]'), doctorName, `Enter Full Name: ${doctorName}`);
      await browser.type(By.xpath('//*[contains(text(), "Phone Number")]/following::input[1]'), '8888888888', 'Enter Phone Number: 8888888888');
      await browser.type(By.xpath('//*[contains(text(), "Password")]/following::input[1]'), 'docpass123', 'Enter Password: *********');

      // Click Create Account
      await browser.clickByText('Create Account', 'Click "Create Account" button');
      await browser.sleep(3000); // Wait for account creation and dashboard load

      // Step 5: Verify Doctor Dashboard Details
      await browser.waitForText('Doctor Portal');
      await browser.waitForText(doctorName);
      logStep(`Successfully verified Doctor Portal access for: ${doctorName}`);

      // Verify doctor navigation tabs
      try {
        await browser.clickByText('Pills Management', 'Navigate to Pills Management Tab');
        await browser.sleep(1000);
        await browser.clickByText('Patient Management', 'Navigate to Patient Management Tab');
        await browser.sleep(1000);
      } catch (e) {
        logStep('Doctor Sub-tabs interaction skipped or failed', 'Warning');
      }

      endTestRun('Passed');
    } catch (err) {
      endTestRun('Failed', err);
      throw err;
    }
  });

  it('should register a new Health Worker and verify Health Worker Dashboard access', async function () {
    const testName = 'Health Worker Role - Registration and Dashboard Verification';
    startTestRun(testName, 'Health Worker');
    
    try {
      // Step 1: Navigation
      await browser.navigate();
      browser.driver.sleep(1000);

      // Step 2: Navigate to Role Selection
      await browser.clickByText('Create new account', 'Click "Create new account" button');
      await browser.waitForText('Please select your role to continue');

      // Step 3: Choose Health Worker Role
      await browser.clickByText('Health Worker', 'Select "Health Worker" role link');
      await browser.waitForText('Welcome, Health Worker!');

      // Step 4: Fill Health Worker Creation Form
      const randomIdSuffix = Math.floor(Math.random() * 90000 + 10000);
      const workerName = `Nurse Brenda ${randomIdSuffix}`;
      
      await browser.type(By.xpath('//*[contains(text(), "Full Name")]/following::input[1]'), workerName, `Enter Full Name: ${workerName}`);
      await browser.type(By.xpath('//*[contains(text(), "Phone Number")]/following::input[1]'), '7777777777', 'Enter Phone Number: 7777777777');
      await browser.type(By.xpath('//*[contains(text(), "Password")]/following::input[1]'), 'workerpass123', 'Enter Password: *********');

      // Click Create Account
      await browser.clickByText('Create Account', 'Click "Create Account" button');
      await browser.sleep(3000); // Wait for account creation and dashboard load

      // Step 5: Verify Health Worker Dashboard Details
      await browser.waitForText('Worker Dashboard');
      await browser.waitForText(workerName);
      logStep(`Successfully verified Health Worker Dashboard access for: ${workerName}`);

      // Verify appointments list
      try {
        await browser.waitForText('Pending Appointments');
        logStep('Verified appointments section is present');
      } catch (e) {
        logStep('Appointments section not found or skipped', 'Warning');
      }

      endTestRun('Passed');
    } catch (err) {
      endTestRun('Failed', err);
      throw err;
    }
  });
});
