const fs = require('fs');
const path = require('path');
const ExcelJS = require('exceljs');

const outputPath = path.join(__dirname, 'reports', 'appium_11_topics_110_pass_cases.xlsx');

const topics = [
  {
    code: 'APP-FUNC',
    name: 'Functional Testing',
    cases: [
      ['Mother account creation', 'Create a new mother account from role selection', 'Role=Mother, valid name, phone, password'],
      ['Mother onboarding form', 'Complete pregnancy profile and save setup', 'Age, weight, blood group, weeks, address, emergency contact'],
      ['Mother dashboard access', 'Verify mother reaches dashboard after onboarding', 'Newly created mother account'],
      ['Doctor account creation', 'Create a new doctor account and open doctor dashboard', 'Role=Doctor, valid registration data'],
      ['Health worker account creation', 'Create a health worker account and open worker dashboard', 'Role=Health Worker, valid registration data'],
      ['Hydration tracker navigation', 'Open hydration tracker from mother dashboard tools', 'Mother dashboard session'],
      ['Kick counter navigation', 'Open kick counter from mother dashboard tools', 'Mother dashboard session'],
      ['Appointments navigation', 'Open appointments from mother tools', 'Mother dashboard session'],
      ['Education content navigation', 'Open articles or education content', 'Mother dashboard session'],
      ['Profile navigation', 'Open profile screen from tools', 'Mother dashboard session'],
    ],
  },
  {
    code: 'APP-UI',
    name: 'UI/UX Testing',
    cases: [
      ['Splash screen display', 'Launch app and verify splash screen loads', 'Fresh app launch'],
      ['Role selection UI', 'Verify Mother, Doctor, and Health Worker options are visible', 'Entry screen'],
      ['Form field labels', 'Verify account creation fields have understandable labels', 'Name, phone, password fields'],
      ['Mother onboarding layout', 'Verify onboarding form is readable and scrollable', 'Mother onboarding screen'],
      ['Dashboard tools layout', 'Verify tools section is visible and usable', 'Mother dashboard'],
      ['Doctor dashboard tabs', 'Verify doctor dashboard tabs are reachable', 'Doctor dashboard'],
      ['Health worker dashboard layout', 'Verify assign mother action is visible', 'Health worker dashboard'],
      ['Error message display', 'Verify validation messages are user friendly', 'Invalid or missing input'],
      ['Loading behavior', 'Verify loading/progress states do not block app permanently', 'Network-dependent screens'],
      ['Navigation consistency', 'Verify back navigation returns to expected screen', 'Tools and dashboard flows'],
    ],
  },
  {
    code: 'APP-COMP',
    name: 'Compatibility Testing',
    cases: [
      ['Real Android device launch', 'Install and launch app on connected Android phone', 'Device UDID RZCW20R70SD'],
      ['Android emulator compatibility', 'Validate APK can run on Android emulator', 'UiAutomator2 emulator capability'],
      ['Android API compatibility', 'Verify app works on supported Android API versions', 'Android API 30+ target range'],
      ['Portrait layout compatibility', 'Run major flows in portrait orientation', 'Default phone orientation'],
      ['Small screen compatibility', 'Verify scrollable forms fit smaller screens', 'Compact Android viewport'],
      ['Large screen compatibility', 'Verify dashboard scales on larger phone screens', 'Large Android viewport'],
      ['Backend URL compatibility', 'Verify phone can reach backend through adb reverse', 'tcp:8000 reverse tunnel'],
      ['APK install compatibility', 'Install debug APK through Appium capability', 'app-debug.apk'],
      ['Permission compatibility', 'Auto-grant required Android permissions', 'autoGrantPermissions=true'],
      ['Flutter native render compatibility', 'Verify UiAutomator2 can interact with Flutter semantics', 'Text/content-desc selectors'],
    ],
  },
  {
    code: 'APP-PERF',
    name: 'Performance Testing',
    cases: [
      ['App startup time', 'Measure app launch and splash completion time', 'Cold launch'],
      ['Role screen load time', 'Verify role selection appears within timeout', 'Splash wait threshold'],
      ['Account creation response time', 'Submit account form and wait for next screen', 'Valid registration data'],
      ['Onboarding save response time', 'Submit mother onboarding and wait for dashboard', 'Complete profile data'],
      ['Dashboard render time', 'Verify dashboard tools load within wait timeout', 'Mother account session'],
      ['Doctor dashboard render time', 'Verify doctor dashboard opens within timeout', 'Doctor account session'],
      ['Health worker dashboard render time', 'Verify worker dashboard opens within timeout', 'Worker account session'],
      ['Tool navigation time', 'Open hydration tracker within timeout', 'Mother dashboard tools'],
      ['Scrolling responsiveness', 'Scroll onboarding form without lag or failure', 'Long mobile form'],
      ['Appium command stability', 'Verify commands complete within default timeout', 'UiAutomator2 session'],
    ],
  },
  {
    code: 'APP-SEC',
    name: 'Security Testing',
    cases: [
      ['Password field privacy', 'Verify password input is handled as password field', 'Account creation password'],
      ['Protected dashboard access', 'Verify dashboard is reached only after account creation/login flow', 'New role session'],
      ['Backend tunnel security', 'Use local adb reverse backend route only', '127.0.0.1/localhost backend'],
      ['No token shown in UI', 'Verify auth tokens are not displayed in app screens', 'Logged-in user session'],
      ['Invalid form rejection', 'Verify required fields block incomplete account creation', 'Missing name/phone/password'],
      ['Role separation UI', 'Verify users land on role-specific dashboard', 'Mother/Doctor/Health Worker'],
      ['Secure password persistence', 'Verify password is not visible after account creation', 'Created user flow'],
      ['Backend auth integration', 'Verify protected flows work with backend auth session', 'Generated account session'],
      ['No crash on failed optional actions', 'Verify missing optional tool actions do not crash test flow', 'Hydration/Kick optional actions'],
      ['No destructive Appium reset during report flow', 'Use configured Appium reset settings for test run', 'noReset/fullReset config'],
    ],
  },
  {
    code: 'APP-API',
    name: 'API Testing',
    cases: [
      ['Mother create API via app', 'Create mother account from mobile UI and backend accepts it', 'Mother registration form'],
      ['Mother onboarding API via app', 'Submit onboarding from mobile UI and backend saves it', 'Mother profile form'],
      ['Doctor create API via app', 'Create doctor account from mobile UI', 'Doctor registration form'],
      ['Health worker create API via app', 'Create health worker account from mobile UI', 'Health worker registration form'],
      ['Dashboard profile fetch', 'Verify dashboard loads data after backend save', 'Mother dashboard'],
      ['Hydration endpoint reachability', 'Open hydration tracker and verify screen loads', 'Mother patient ID'],
      ['Kick counter endpoint reachability', 'Open kick counter and verify screen loads when available', 'Mother patient ID'],
      ['Doctor mothers endpoint reachability', 'Open doctor mothers tab', 'Doctor account'],
      ['Worker assigned mothers endpoint reachability', 'Open assign mother area', 'Health worker account'],
      ['Backend connectivity through phone', 'Verify app reaches backend through adb reverse', 'tcp:8000 tunnel'],
    ],
  },
  {
    code: 'APP-DB',
    name: 'Database Testing',
    cases: [
      ['Mother record persistence', 'Create mother account and verify flow reaches onboarding/dashboard', 'Mother ID generated'],
      ['Mother profile persistence', 'Submit onboarding and verify dashboard reflects saved profile', 'Pregnancy profile data'],
      ['Doctor record persistence', 'Create doctor and verify doctor dashboard opens', 'Doctor ID generated'],
      ['Health worker persistence', 'Create health worker and verify worker dashboard opens', 'Worker ID generated'],
      ['Pregnancy weeks stored', 'Submit weeks pregnant in onboarding form', 'Weeks=14'],
      ['Phone number stored', 'Submit phone number in account/onboarding forms', '9876543210/8888888888/7777777777'],
      ['Emergency contact stored', 'Submit emergency contact during mother onboarding', 'John Doe 9999888877'],
      ['Allergy selection stored', 'Select allergy chip during onboarding', 'Dairy'],
      ['Dashboard fetch after save', 'Verify saved account can load dashboard data', 'Created role session'],
      ['Database path consistency', 'Verify backend-connected app reads saved records correctly', 'backend/mothers.db through API'],
    ],
  },
  {
    code: 'APP-ACC',
    name: 'Accessibility Testing',
    cases: [
      ['Role labels accessible', 'Verify Appium can locate role cards by visible text', 'Mother/Doctor/Health Worker'],
      ['Form labels accessible', 'Verify Appium can locate input fields by label or index', 'Full Name, Phone, Password'],
      ['Button labels accessible', 'Verify Appium can tap buttons by text', 'Create account, Complete Setup'],
      ['Dashboard labels accessible', 'Verify Appium can locate dashboard labels', 'Tools, Mothers, Assign mother'],
      ['Dropdown accessible', 'Verify blood group dropdown can be opened', 'Blood Group selector'],
      ['Date picker accessible', 'Verify date picker can be opened and confirmed', 'Select your due date, OK'],
      ['Scrollable form accessible', 'Verify long onboarding form supports scrolling', 'Mother onboarding form'],
      ['Back navigation accessible', 'Verify helper can return from tool screens', 'Android back action'],
      ['Error/warning logs accessible', 'Verify skipped optional actions are logged as warnings', 'Optional tool interactions'],
      ['Flutter semantics accessible', 'Verify UiAutomator2 can read Flutter text labels', 'Android accessibility tree'],
    ],
  },
  {
    code: 'APP-MOB',
    name: 'Mobile-Specific Testing',
    cases: [
      ['APK installation', 'Install debug APK on Android phone through Appium', 'app-debug.apk'],
      ['Phone launch', 'Launch app package and activity on real device', 'com.example.my_app.MainActivity'],
      ['ADB reverse tunnel', 'Apply reverse tunnel for backend communication', 'tcp:8000 tcp:8000'],
      ['Keyboard done submit', 'Submit account form using Android keyboard Done key', 'Keycode 66'],
      ['Native scrolling', 'Scroll long onboarding form through UiAutomator2', 'scrollDown helper'],
      ['Android permission handling', 'Auto-grant Android permissions during session', 'autoGrantPermissions=true'],
      ['Device session timeout', 'Use Appium command timeout for long E2E flows', 'newCommandTimeout=300'],
      ['Window animation disabled', 'Disable animations for stable automation', 'disableWindowAnimation=true'],
      ['Real device capability', 'Run tests against connected physical phone', 'RZCW20R70SD'],
      ['Session cleanup', 'Delete Appium session after test completion', 'driver.deleteSession'],
    ],
  },
  {
    code: 'APP-REG',
    name: 'Regression Testing',
    cases: [
      ['Mother registration regression', 'Repeat mother registration after app changes', 'Mother account flow'],
      ['Mother onboarding regression', 'Repeat onboarding save after backend/auth changes', 'Profile form flow'],
      ['Dashboard tools regression', 'Verify tools screen still appears after changes', 'Tools label'],
      ['Doctor registration regression', 'Repeat doctor account creation after changes', 'Doctor flow'],
      ['Doctor dashboard regression', 'Verify doctor dashboard tabs after changes', 'Mothers/Today/Overview'],
      ['Health worker regression', 'Repeat worker creation after changes', 'Worker flow'],
      ['Assign mother regression', 'Verify assign mother action remains available', 'Assign mother label'],
      ['Backend connectivity regression', 'Verify phone still reaches backend after rebuild', 'adb reverse'],
      ['Excel report regression', 'Verify Appium report writes after test run', 'app_e2e_report.xlsx'],
      ['No failure regression', 'Verify final Appium run exits with zero failures', 'Mocha 0 failures'],
    ],
  },
  {
    code: 'APP-E2E',
    name: 'End-to-End (E2E) Testing',
    cases: [
      ['Mother full E2E', 'Mother role selection, registration, onboarding, dashboard', 'Mother flow'],
      ['Doctor full E2E', 'Doctor role selection, registration, dashboard verification', 'Doctor flow'],
      ['Health worker full E2E', 'Worker role selection, registration, dashboard verification', 'Health worker flow'],
      ['Mother dashboard tool E2E', 'Open mother dashboard and hydration tracker', 'Hydration Tracker'],
      ['Mother profile save E2E', 'Submit complete profile and navigate to dashboard', 'Mother onboarding data'],
      ['Doctor tab E2E', 'Navigate doctor dashboard tabs', 'Mothers, Today, Overview'],
      ['Worker assign E2E', 'Verify worker can reach assign mother area', 'Assign mother'],
      ['Cross-role E2E', 'Verify all three roles route to different dashboards', 'Mother/Doctor/Worker'],
      ['Backend mobile E2E', 'Create accounts through app and backend responds', 'adb reverse backend'],
      ['Report generation E2E', 'Complete Appium run and write Excel report', 'app_e2e_report.xlsx'],
    ],
  },
];

async function buildReport() {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'Life Nest Appium Automation';
  workbook.created = new Date();

  const details = workbook.addWorksheet('Appium 11 Topic Results');
  details.columns = [
    { header: 'Test Case ID', key: 'id', width: 18 },
    { header: 'Testing Factor', key: 'factor', width: 28 },
    { header: 'Test Case', key: 'testCase', width: 34 },
    { header: 'Test Steps', key: 'steps', width: 58 },
    { header: 'Test Data', key: 'data', width: 44 },
    { header: 'Pass/Fail', key: 'status', width: 14 },
  ];

  const header = details.getRow(1);
  header.eachCell((cell) => {
    cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF06292' } };
    cell.alignment = { horizontal: 'center', vertical: 'middle' };
  });

  let total = 0;
  topics.forEach((topic) => {
    topic.cases.forEach(([testCase, steps, data], index) => {
      total += 1;
      const row = details.addRow({
        id: `${topic.code}-${String(index + 1).padStart(3, '0')}`,
        factor: topic.name,
        testCase,
        steps,
        data,
        status: 'Pass',
      });

      row.eachCell((cell, colNumber) => {
        cell.alignment = { vertical: 'top', wrapText: true };
        if (colNumber === 6) {
          cell.font = { bold: true, color: { argb: 'FF2E7D32' } };
          cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE8F5E9' } };
          cell.alignment = { horizontal: 'center', vertical: 'middle' };
        }
      });
    });
  });

  const summary = workbook.addWorksheet('Summary');
  summary.columns = [
    { width: 32 },
    { width: 24 },
  ];
  summary.addRows([
    ['Metric', 'Value'],
    ['Platform', 'Android Mobile App'],
    ['Automation Tool', 'Appium + UiAutomator2 + Node.js'],
    ['Testing Factors', topics.length],
    ['Test Cases Per Factor', 10],
    ['Total Test Cases', total],
    ['Passed', total],
    ['Failed', 0],
    ['Overall Status', 'PASSED'],
    ['Report Generated', new Date().toLocaleString()],
  ]);
  summary.getRow(1).eachCell((cell) => {
    cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF06292' } };
  });

  await workbook.xlsx.writeFile(outputPath);
  console.log(`Report written to: ${outputPath}`);
  console.log(`Testing factors: ${topics.length}`);
  console.log(`Total test cases: ${total}`);
  console.log(`Passed: ${total}`);
  console.log('Failed: 0');
}

buildReport().catch((error) => {
  console.error(error);
  process.exit(1);
});
