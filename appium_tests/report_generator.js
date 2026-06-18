const ExcelJS = require('exceljs');
const fs = require('fs');
const path = require('path');
const config = require('./config');

/**
 * Generates a styled Excel workbook analyzing the Appium test run results.
 * @param {Array} testRuns - Array of test run results accumulated by helpers.js
 */
async function generateExcelReport(testRuns) {
  console.log('\nGenerating Excel Analysis Report...');

  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'Life Nest Mobile Automation Engine';
  workbook.created = new Date();

  // Color Definitions (Maternal Pink Theme)
  const colors = {
    primaryPink: 'FFF06292',
    lightPink: 'FFFFF0F2',
    headerPink: 'FFF8BBD0',
    darkPurple: 'FF4A148C',
    white: 'FFFFFFFF',
    passGreenBg: 'FFE8F5E9',
    passGreenText: 'FF2E7D32',
    failRedBg: 'FFFFEBEE',
    failRedText: 'FFC62828',
    warnAmberBg: 'FFFFF8E1',
    warnAmberText: 'FFF57F17',
    borderGray: 'FFD6D6D6',
    zebraGray: 'FFF9F9F9'
  };

  const thinBorder = {
    top: { style: 'thin', color: { argb: colors.borderGray } },
    left: { style: 'thin', color: { argb: colors.borderGray } },
    bottom: { style: 'thin', color: { argb: colors.borderGray } },
    right: { style: 'thin', color: { argb: colors.borderGray } }
  };

  const statusStyle = (status) => {
    if (status === 'Passed') return { bg: colors.passGreenBg, text: colors.passGreenText };
    if (status === 'Failed') return { bg: colors.failRedBg, text: colors.failRedText };
    return { bg: colors.warnAmberBg, text: colors.warnAmberText }; // Warning
  };

  // --- SHEET 1: SUMMARY DASHBOARD ---
  const summarySheet = workbook.addWorksheet('Summary Dashboard', {
    views: [{ showGridLines: true }]
  });

  const totalTests = testRuns.length;
  const passedTests = testRuns.filter((t) => t.status === 'Passed').length;
  const failedTests = totalTests - passedTests;
  const passRate = totalTests > 0 ? Math.round((passedTests / totalTests) * 100) : 0;
  const totalDuration = testRuns.reduce((acc, t) => acc + t.duration, 0).toFixed(2);

  summarySheet.columns = [
    { width: 4 },
    { width: 28 },
    { width: 18 },
    { width: 8 },
    { width: 18 },
    { width: 28 }
  ];

  summarySheet.mergeCells('B2:F3');
  const titleCell = summarySheet.getCell('B2');
  titleCell.value = 'LIFE NEST MOBILE (APPIUM) TEST AUTOMATION DASHBOARD';
  titleCell.font = { name: 'Segoe UI', size: 16, bold: true, color: { argb: colors.white } };
  titleCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: colors.primaryPink } };
  titleCell.alignment = { vertical: 'middle', horizontal: 'center' };

  summarySheet.addRow([]);
  summarySheet.addRow([]);

  const metrics = [
    ['Total Test Cases', totalTests],
    ['Passed Cases', passedTests],
    ['Failed Cases', failedTests],
    ['Pass Rate (%)', `${passRate}%`],
    ['Total Duration', `${totalDuration} seconds`],
    ['Report Generated On', new Date().toLocaleString()]
  ];

  summarySheet.getCell('B5').value = 'Test Metric';
  summarySheet.getCell('C5').value = 'Value';

  [summarySheet.getCell('B5'), summarySheet.getCell('C5')].forEach((cell) => {
    cell.font = { name: 'Segoe UI', size: 11, bold: true, color: { argb: colors.darkPurple } };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: colors.headerPink } };
    cell.border = thinBorder;
    cell.alignment = { horizontal: 'center' };
  });

  metrics.forEach((metric, index) => {
    const rowNum = 6 + index;
    const keyCell = summarySheet.getCell(`B${rowNum}`);
    const valCell = summarySheet.getCell(`C${rowNum}`);

    keyCell.value = metric[0];
    keyCell.font = { name: 'Segoe UI', size: 10, bold: true };
    keyCell.border = thinBorder;
    keyCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: index % 2 === 0 ? colors.zebraGray : colors.white } };

    valCell.value = metric[1];
    valCell.font = { name: 'Segoe UI', size: 10 };
    valCell.border = thinBorder;
    valCell.alignment = { horizontal: 'center' };
    valCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: index % 2 === 0 ? colors.zebraGray : colors.white } };

    if (metric[0] === 'Pass Rate (%)') {
      valCell.font = { name: 'Segoe UI', size: 11, bold: true, color: { argb: passRate === 100 ? colors.passGreenText : colors.failRedText } };
      valCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: passRate === 100 ? colors.passGreenBg : colors.failRedBg } };
    }
  });

  // Side block: mobile platform context.
  summarySheet.getCell('E5').value = 'Platform Context';
  summarySheet.getCell('F5').value = 'Configuration';

  [summarySheet.getCell('E5'), summarySheet.getCell('F5')].forEach((cell) => {
    cell.font = { name: 'Segoe UI', size: 11, bold: true, color: { argb: colors.darkPurple } };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: colors.headerPink } };
    cell.border = thinBorder;
    cell.alignment = { horizontal: 'center' };
  });

  const caps = config.capabilities;
  const sideDetails = [
    ['Test Environment', 'Flutter Android (Native)'],
    ['Automation Engine', 'Appium + UiAutomator2'],
    ['App Package', caps['appium:appPackage'] || 'n/a'],
    ['Device', caps['appium:deviceName'] || 'Android Device'],
    ['Default Timeout', `${config.defaultTimeout / 1000} seconds`],
    ['Test Runner', 'Mocha + WebdriverIO']
  ];

  sideDetails.forEach((detail, index) => {
    const rowNum = 6 + index;
    const keyCell = summarySheet.getCell(`E${rowNum}`);
    const valCell = summarySheet.getCell(`F${rowNum}`);

    keyCell.value = detail[0];
    keyCell.font = { name: 'Segoe UI', size: 10, bold: true };
    keyCell.border = thinBorder;
    keyCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: index % 2 === 0 ? colors.zebraGray : colors.white } };

    valCell.value = detail[1];
    valCell.font = { name: 'Segoe UI', size: 10 };
    valCell.border = thinBorder;
    valCell.alignment = { horizontal: 'center' };
    valCell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: index % 2 === 0 ? colors.zebraGray : colors.white } };
  });

  // --- SHEET 2: DETAILED STEP LOGS ---
  const detailsSheet = workbook.addWorksheet('Execution Details', {
    views: [{ showGridLines: true }]
  });

  detailsSheet.columns = [
    { header: 'Test Case Name', key: 'testName', width: 34 },
    { header: 'Target Role', key: 'role', width: 15 },
    { header: 'Step #', key: 'stepIndex', width: 8 },
    { header: 'Time', key: 'time', width: 12 },
    { header: 'Step Description', key: 'description', width: 62 },
    { header: 'Step Status', key: 'stepStatus', width: 12 },
    { header: 'Test Duration (s)', key: 'testDuration', width: 18 }
  ];

  const headerRow = detailsSheet.getRow(1);
  headerRow.height = 28;
  headerRow.eachCell((cell) => {
    cell.font = { name: 'Segoe UI', size: 11, bold: true, color: { argb: colors.white } };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: colors.primaryPink } };
    cell.border = thinBorder;
    cell.alignment = { vertical: 'middle', horizontal: 'center' };
  });

  let zebraToggle = false;

  testRuns.forEach((test) => {
    zebraToggle = !zebraToggle;
    const baseRowColor = zebraToggle ? colors.zebraGray : colors.white;
    const totalSteps = test.steps.length;

    if (totalSteps === 0) {
      const newRow = detailsSheet.addRow({
        testName: test.name,
        role: test.role,
        stepIndex: '-',
        time: '-',
        description: test.error ? `Failed to initialize test: ${test.error}` : 'No execution steps recorded',
        stepStatus: test.status,
        testDuration: test.duration
      });
      const st = statusStyle(test.status);
      newRow.eachCell((cell, colNum) => {
        cell.border = thinBorder;
        cell.font = { name: 'Segoe UI', size: 10 };
        cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: baseRowColor } };
        if (colNum === 6) {
          cell.font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: st.text } };
          cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: st.bg } };
        }
      });
      return;
    }

    test.steps.forEach((step, idx) => {
      const newRow = detailsSheet.addRow({
        testName: idx === 0 ? test.name : '',
        role: idx === 0 ? test.role : '',
        stepIndex: idx + 1,
        time: step.timestamp,
        description: step.description,
        stepStatus: step.status,
        testDuration: idx === 0 ? test.duration : ''
      });

      const st = statusStyle(step.status);
      newRow.eachCell((cell, colNum) => {
        cell.border = thinBorder;
        cell.font = { name: 'Segoe UI', size: 10 };
        cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: baseRowColor } };

        if (colNum === 3 || colNum === 4 || colNum === 7) {
          cell.alignment = { horizontal: 'center' };
        }

        if (colNum === 6) {
          cell.alignment = { horizontal: 'center' };
          cell.font = { name: 'Segoe UI', size: 9, bold: true, color: { argb: st.text } };
          cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: st.bg } };
        }

        if ((colNum === 1 || colNum === 2) && idx === 0) {
          cell.font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: colors.darkPurple } };
        }
      });
    });

    const spacerRow = detailsSheet.addRow([]);
    spacerRow.eachCell((cell) => {
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: colors.white } };
    });
  });

  // --- SHEET 3: REQUESTED TEST CASE RESULT FORMAT ---
  const resultSheet = workbook.addWorksheet('Test Case Results', {
    views: [{ showGridLines: true }]
  });

  resultSheet.columns = [
    { header: 'Test ID', key: 'testId', width: 16 },
    { header: 'Test Case', key: 'testCase', width: 34 },
    { header: 'Test Name', key: 'testName', width: 52 },
    { header: 'Data', key: 'data', width: 58 },
    { header: 'Pass / Fail', key: 'passFail', width: 16 }
  ];

  resultSheet.getRow(1).eachCell((cell) => {
    cell.font = { name: 'Segoe UI', size: 11, bold: true, color: { argb: colors.white } };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: colors.primaryPink } };
    cell.border = thinBorder;
    cell.alignment = { vertical: 'middle', horizontal: 'center' };
  });

  testRuns.forEach((test, index) => {
    const row = resultSheet.addRow({
      testId: `APP-E2E-${String(index + 1).padStart(3, '0')}`,
      testCase: `${test.role} App E2E`,
      testName: test.name,
      data: test.steps.map((step) => step.description).join(' | '),
      passFail: test.status === 'Passed' ? 'Pass' : 'Fail'
    });

    row.eachCell((cell, colNum) => {
      cell.border = thinBorder;
      cell.font = { name: 'Segoe UI', size: 10 };
      cell.alignment = { vertical: 'top', wrapText: true };
      if (colNum === 5) {
        const passed = cell.value === 'Pass';
        cell.font = { name: 'Segoe UI', size: 10, bold: true, color: { argb: passed ? colors.passGreenText : colors.failRedText } };
        cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: passed ? colors.passGreenBg : colors.failRedBg } };
        cell.alignment = { vertical: 'middle', horizontal: 'center' };
      }
    });
  });

  const finalReportPath = path.resolve(config.reportPath);
  fs.mkdirSync(path.dirname(finalReportPath), { recursive: true });
  await workbook.xlsx.writeFile(finalReportPath);
  console.log(`Report successfully written to: ${finalReportPath}`);
  return finalReportPath;
}

module.exports = {
  generateExcelReport
};
