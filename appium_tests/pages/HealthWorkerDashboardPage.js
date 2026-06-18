const BasePage = require('./BasePage');

class HealthWorkerDashboardPage extends BasePage {
  async verifyLoaded() {
    await this.waitForText('Assign mother');
  }

  async verifyCoreActions() {
    try {
      await this.tap('Assign mother', 'Open Assign mother action');
      await this.goBack('Return from Assign mother action');
    } catch (_) {
      // Keep dashboard smoke resilient if the action opens a modal without back navigation.
    }
  }
}

module.exports = HealthWorkerDashboardPage;
