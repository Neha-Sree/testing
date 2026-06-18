const Mocha = require('mocha');
const path = require('path');
const { getTestRuns } = require('./helpers');
const { generateExcelReport } = require('./report_generator');

const mocha = new Mocha({
  timeout: 240000, // 4 minutes maximum per test case
  reporter: 'spec'
});

mocha.addFile(path.join(__dirname, 'test_e2e.js'));

console.log('==================================================');
console.log('     LIFE NEST MOBILE TEST AUTOMATION ENGINE      ');
console.log('             (Appium + UiAutomator2)              ');
console.log('==================================================');
console.log('Connecting to Appium server and starting tests...');

mocha.run(async (failures) => {
  console.log('\nAll tests completed. Compiling results...');

  try {
    const runs = getTestRuns();
    const reportPath = await generateExcelReport(runs);

    console.log('\n==================================================');
    console.log(`Test Execution Finished with ${failures} failure(s).`);
    console.log('Analysis Report generated at:');
    console.log(`  ${reportPath}`);
    console.log('==================================================\n');

    process.exit(failures ? 1 : 0);
  } catch (err) {
    console.error('CRITICAL: Failed to generate Excel report:', err);
    process.exit(1);
  }
});
