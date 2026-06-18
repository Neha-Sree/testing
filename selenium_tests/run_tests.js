const Mocha = require('mocha');
const path = require('path');
const { getTestRuns } = require('./helpers');
const { generateExcelReport } = require('./report_generator');

// Instantiate a Mocha instance
const mocha = new Mocha({
  timeout: 120000, // 2 minutes maximum per test case
  reporter: 'spec'  // standard spec reporter for console visibility
});

// Add our E2E test file
mocha.addFile(path.join(__dirname, 'test_e2e.js'));

console.log('==================================================');
console.log('       LIFE NEST WEB TEST AUTOMATION ENGINE       ');
console.log('==================================================');
console.log('Initializing Selenium WebDriver and starting tests...');

// Run the tests
mocha.run(async (failures) => {
  console.log('\nAll tests completed. Compiling results...');
  
  try {
    const runs = getTestRuns();
    
    // Generate the styled Excel analysis report
    const reportPath = await generateExcelReport(runs);
    
    console.log('\n==================================================');
    console.log(`Test Execution Finished with ${failures} failure(s).`);
    console.log(`Analysis Report generated at:`);
    console.log(`  ${reportPath}`);
    console.log('==================================================\n');
    
    process.exit(failures ? 1 : 0);
  } catch (err) {
    console.error('CRITICAL: Failed to generate Excel report:', err);
    process.exit(1);
  }
});
