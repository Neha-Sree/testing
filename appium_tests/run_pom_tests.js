const fs = require('fs');
const path = require('path');
const Mocha = require('mocha');

function ensureFolders() {
  [
    path.join(__dirname, 'reports'),
    path.join(__dirname, 'reports', 'excel'),
    path.join(__dirname, 'reports', 'html'),
    path.join(__dirname, 'screenshots'),
    path.join(__dirname, 'logs'),
    path.join(__dirname, 'test_data')
  ].forEach((dir) => {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  });
}

ensureFolders();

const defaultExcelPath = path.join(__dirname, 'reports', 'excel', `appium_e2e_report_${Date.now()}.xlsx`);
process.env.REPORT_PATH = process.env.REPORT_PATH || defaultExcelPath;
const { getTestRuns } = require('./helpers');
const { generateExcelReport } = require('./report_generator');
const { generateHtmlReport } = require('./utils/html_report_generator');
const { log, logPath } = require('./utils/logger');

const mocha = new Mocha({
  timeout: 300000,
  reporter: 'spec'
});

mocha.addFile(path.join(__dirname, 'tests', 'e2e_pom.test.js'));

log('==================================================');
log(' LIFE NEST MOBILE POM APPIUM AUTOMATION ENGINE');
log('==================================================');
log(`Execution log: ${logPath}`);

mocha.run(async (failures) => {
  log(`Mocha execution completed with ${failures} failure(s).`);
  try {
    const runs = getTestRuns();
    const excelReportPath = await generateExcelReport(runs);
    const htmlReportPath = generateHtmlReport(runs);

    log(`Excel report generated: ${excelReportPath}`);
    log(`HTML report generated: ${htmlReportPath}`);
    log(`Overall status: ${failures ? 'FAILED' : 'PASSED'}`);
    process.exit(failures ? 1 : 0);
  } catch (error) {
    console.error('Failed to generate Appium reports:', error);
    process.exit(1);
  }
});
