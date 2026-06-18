class BasePage {
  constructor(driver, app) {
    this.driver = driver;
    this.app = app;
  }

  async waitForAppReady() {
    await this.app.waitForAppReady();
  }

  async tap(label, description) {
    await this.app.tap(label, description);
  }

  async type(label, value, fieldIndex, description) {
    await this.app.typeInField(label, value, {
      fieldIndex,
      stepDescription: description || `Enter ${label}`
    });
  }

  async waitForText(text, timeout) {
    await this.app.waitForText(text, timeout);
  }

  async scrollDown(fraction = 0.45) {
    await this.app.scrollDown(fraction);
  }

  async goBack(description) {
    await this.app.goBack(description);
  }
}

module.exports = BasePage;
