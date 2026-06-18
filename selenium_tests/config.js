const path = require('path');

module.exports = {
  // The base URL where the local Flutter Web application is hosted
  baseUrl: process.env.BASE_URL || 'http://localhost:8080',
  
  // The browser type to run (chrome, firefox, edge)
  browserName: process.env.BROWSER || 'chrome',
  
  // Whether to run the browser in headless mode (headless Chrome)
  headless: process.env.HEADLESS === 'true' || false,
  
  // Default timeout for element search and synchronization in milliseconds
  defaultTimeout: parseInt(process.env.TIMEOUT || '10000', 10),
  
  // Output path for the generated Excel test report
  reportPath: process.env.REPORT_PATH || path.join(__dirname, 'reports', 'web_e2e_report.xlsx')
};
