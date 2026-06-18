const fs = require('fs');
const path = require('path');

const screenshotsDir = path.join(__dirname, '..', 'screenshots');

function ensureScreenshotsDir() {
  if (!fs.existsSync(screenshotsDir)) {
    fs.mkdirSync(screenshotsDir, { recursive: true });
  }
}

async function captureScreenshot(driver, name) {
  ensureScreenshotsDir();
  const safeName = String(name || 'screenshot').replace(/[^a-z0-9_-]+/gi, '_').toLowerCase();
  const filePath = path.join(screenshotsDir, `${safeName}_${Date.now()}.png`);
  const base64 = await driver.takeScreenshot();
  fs.writeFileSync(filePath, Buffer.from(base64, 'base64'));
  return filePath;
}

module.exports = {
  captureScreenshot,
  screenshotsDir
};
