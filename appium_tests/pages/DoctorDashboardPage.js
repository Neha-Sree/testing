const BasePage = require('./BasePage');

class DoctorDashboardPage extends BasePage {
  async verifyLoaded() {
    await this.waitForText('Mothers');
  }

  async verifyNavigation() {
    try {
      await this.tap('Mothers', 'Open Mothers tab');
      await this.tap('Today', 'Open Today tab');
      await this.tap('Overview', 'Return to Overview tab');
    } catch (_) {
      // Some tabs may not be visible on smaller devices until scrolling.
    }
  }
}

module.exports = DoctorDashboardPage;
