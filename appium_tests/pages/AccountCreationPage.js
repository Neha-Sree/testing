const BasePage = require('./BasePage');

class AccountCreationPage extends BasePage {
  async createAccount({ fullName, phone, password }) {
    await this.type('Full Name', fullName, 0, `Enter full name: ${fullName}`);
    await this.type('Phone Number', phone, 1, `Enter phone number: ${phone}`);
    await this.type('Password', password, 2, 'Enter password');
    await this.driver.pressKeyCode(66);
    await this.app.sleep(1000);
  }
}

module.exports = AccountCreationPage;
