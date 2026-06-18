const BasePage = require('./BasePage');

class MotherOnboardingPage extends BasePage {
  async completeProfile() {
    await this.waitForText("Let's build your profile, Mom!");
    await this.type('Age', '27', 0, 'Enter age: 27');
    await this.driver.pressKeyCode(66);
    await this.type('Weight', '62', 1, 'Enter weight: 62 kg');
    await this.driver.pressKeyCode(66);

    try {
      await this.app.selectDropdownValue('Blood Group', 'AB+', 'Select blood group');
    } catch (_) {
      // Blood group can already have a default value depending on app state.
    }

    await this.type('Weeks Pregnant', '14', 2, 'Enter weeks pregnant: 14');
    await this.driver.pressKeyCode(66);

    try {
      await this.tap('Select your due date', 'Open due date picker');
      await this.tap('OK', 'Confirm due date');
    } catch (_) {
      // Date picker is optional for smoke-compatible runs.
    }

    await this.scrollDown(0.45);
    await this.type('Phone Number', '9876543210', 0, 'Enter profile phone number');
    await this.driver.pressKeyCode(66);
    await this.type('Address', '123 Motherhood Blvd', 1, 'Enter address');
    await this.driver.pressKeyCode(66);
    await this.type('Emergency Contact', 'John Doe 9999888877', 2, 'Enter emergency contact');
    await this.driver.pressKeyCode(66);
    await this.scrollDown(0.45);

    try {
      await this.tap('Dairy', 'Select dairy allergy');
    } catch (_) {
      // Optional chip.
    }

    await this.scrollDown(0.3);
    await this.tap('Complete Setup', 'Submit mother onboarding profile');
    await this.app.sleep(4000);
  }
}

module.exports = MotherOnboardingPage;
