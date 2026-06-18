const fs = require('fs');
const path = require('path');

const logsDir = path.join(__dirname, '..', 'logs');
const logPath = path.join(logsDir, `appium_run_${new Date().toISOString().replace(/[:.]/g, '-')}.log`);

function ensureLogsDir() {
  if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir, { recursive: true });
  }
}

function log(message, level = 'INFO') {
  ensureLogsDir();
  const line = `[${new Date().toISOString()}] [${level}] ${message}`;
  fs.appendFileSync(logPath, `${line}\n`);
  console.log(line);
}

module.exports = {
  log,
  logPath,
  logsDir
};
