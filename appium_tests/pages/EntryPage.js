const BasePage = require('./BasePage');

class EntryPage extends BasePage {
  async openAccountCreation() {
    await this.waitForAppReady();
    await this.tap('Create new account', 'Open account creation flow');
    await this.waitForText('Please select your role to continue');
  }

  async selectRole(roleName) {
    await this.tap(roleName, `Select ${roleName} role`);
    await this.waitForText(`Welcome, ${roleName}!`);
  }
}

module.exports = EntryPage;
