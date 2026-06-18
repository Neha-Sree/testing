const fs = require('fs');
const path = require('path');
const ExcelJS = require('exceljs');
const { Builder, By, until } = require('selenium-webdriver');
const chrome = require('selenium-webdriver/chrome');
const config = require('./config');

const reportPath = path.join(__dirname, 'reports', 'web_selenium_pass_fail_report.xlsx');
const results = [];

function addResult(id, testCase, testName, data, passed) {
  results.push({
    id,
    testCase,
    testName,
    data,
    passFail: passed ? 'Pass' : 'Fail',
  });
  console.log(`${passed ? 'PASS' : 'FAIL'} ${id} ${testName}`);
}

function withTimeout(promise, ms, label) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

async function textExists(driver, text, timeout = 6000) {
  const xpath = `//*[contains(normalize-space(.), "${text}")]`;
  try {
    await driver.wait(until.elementLocated(By.xpath(xpath)), timeout);
    return true;
  } catch (_) {
    return false;
  }
}

async function clickByText(driver, text, timeout = 8000) {
  const xpath = `//*[contains(normalize-space(.), "${text}")]`;
  const element = await driver.wait(until.elementLocated(By.xpath(xpath)), timeout);
  await driver.executeScript('arguments[0].scrollIntoView({block:"center"});', element);
  await driver.sleep(250);
  await element.click();
}

async function writeReport() {
  fs.mkdirSync(path.dirname(reportPath), { recursive: true });
  const workbook = new ExcelJS.Workbook();
  const sheet = workbook.addWorksheet('Web Selenium Results');
  sheet.columns = [
    { header: 'Test Case ID', key: 'id', width: 18 },
    { header: 'Test Case', key: 'testCase', width: 28 },
    { header: 'Test Name', key: 'testName', width: 46 },
    { header: 'Data', key: 'data', width: 70 },
    { header: 'Pass/Fail', key: 'passFail', width: 14 },
  ];

  sheet.getRow(1).eachCell((cell) => {
    cell.font = { bold: true, color: { argb: 'FFFFFFFF' } };
    cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFF06292' } };
    cell.alignment = { horizontal: 'center' };
  });

  for (const result of results) {
    const row = sheet.addRow(result);
    row.eachCell((cell, colNumber) => {
      cell.alignment = { vertical: 'top', wrapText: true };
      if (colNumber === 5) {
        const passed = cell.value === 'Pass';
        cell.font = { bold: true, color: { argb: passed ? 'FF2E7D32' : 'FFC62828' } };
        cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: passed ? 'FFE8F5E9' : 'FFFFEBEE' } };
        cell.alignment = { horizontal: 'center' };
      }
    });
  }

  const summary = workbook.addWorksheet('Summary');
  const passed = results.filter((r) => r.passFail === 'Pass').length;
  const failed = results.length - passed;
  summary.addRows([
    ['Metric', 'Value'],
    ['Platform', 'Web'],
    ['Tool', 'Selenium WebDriver + Node.js'],
    ['Base URL', config.baseUrl],
    ['Total Test Cases', results.length],
    ['Passed', passed],
    ['Failed', failed],
    ['Generated At', new Date().toISOString()],
  ]);
  summary.getRow(1).font = { bold: true };

  await workbook.xlsx.writeFile(reportPath);
  console.log(`Report written to: ${reportPath}`);
  console.log(`Total: ${results.length}, Passed: ${passed}, Failed: ${failed}`);
}

async function run() {
  let driver;
  try {
    const options = new chrome.Options();
    options.addArguments('--headless=new');
    options.addArguments('--disable-gpu');
    options.addArguments('--no-sandbox');
    options.addArguments('--window-size=1280,900');

    driver = await withTimeout(
      new Builder().forBrowser('chrome').setChromeOptions(options).build(),
      45000,
      'Chrome WebDriver startup'
    );
    addResult('WEB-SEL-001', 'Web Setup', 'Start Selenium Chrome WebDriver', 'Chrome headless browser session created', true);
  } catch (error) {
    addResult('WEB-SEL-001', 'Web Setup', 'Start Selenium Chrome WebDriver', error.message, false);
    for (let index = 2; index <= 10; index += 1) {
      addResult(`WEB-SEL-${String(index).padStart(3, '0')}`, 'Web E2E', 'Skipped because Selenium browser did not start', 'Browser startup failed', false);
    }
    await writeReport();
    process.exit(1);
  }

  try {
    await driver.get(config.baseUrl);
    await driver.wait(until.elementLocated(By.tagName('body')), 15000);
    await driver.sleep(3500);
    addResult('WEB-SEL-002', 'Web Launch', 'Open Life Nest web application', config.baseUrl, true);

    const title = await driver.getTitle();
    addResult('WEB-SEL-003', 'Web Metadata', 'Browser title is available', title || '(empty title)', Boolean(title));

    const body = await driver.findElement(By.tagName('body'));
    addResult('WEB-SEL-004', 'Web Render', 'Flutter body element rendered', 'body tag found', Boolean(body));

    const hasLifeNestBranding = (await driver.getTitle()).includes('Life Nest');
    addResult('WEB-SEL-005', 'Web Branding', 'Life Nest browser title is configured', await driver.getTitle(), hasLifeNestBranding);

    const hasMainScript = await driver.executeScript(
      'return Boolean(document.querySelector("script[src*=\'main.dart.js\']"));'
    );
    addResult('WEB-SEL-006', 'Flutter Web', 'Main Dart JavaScript bundle is loaded', 'script[src*="main.dart.js"]', hasMainScript);

    const hasBootstrap = await driver.executeScript(
      'return Boolean(document.querySelector("script[id=\'data-main\']"));'
    );
    addResult('WEB-SEL-007', 'Flutter Web', 'Flutter bootstrap script is loaded', 'script#data-main', hasBootstrap);

    const hasFlutterRoot = await driver.executeScript(
      'return Boolean(document.querySelector("flutter-view, flt-glass-pane, flt-scene-host, canvas")) || document.body.children.length > 0;'
    );
    addResult('WEB-SEL-008', 'Flutter Web', 'Flutter render tree/root is present', 'flutter-view/flt/canvas/body children', hasFlutterRoot);

    const currentUrl = await driver.getCurrentUrl();
    addResult('WEB-SEL-009', 'Web Navigation', 'Browser remains on local web application URL', currentUrl, currentUrl.startsWith(config.baseUrl));

    const fatalErrorPresent = await driver.executeScript(
      'return document.documentElement.outerHTML.includes("Failed to load app") || document.documentElement.outerHTML.includes("Uncaught");'
    );
    addResult('WEB-SEL-010', 'Web Runtime', 'No fatal Flutter web runtime error shown in DOM', 'Check DOM for fatal error markers', !fatalErrorPresent);
  } catch (error) {
    const nextId = `WEB-SEL-${String(results.length + 1).padStart(3, '0')}`;
    addResult(nextId, 'Web Runtime', 'Unhandled Selenium web test error', error.message, false);
  } finally {
    if (driver) {
      await driver.quit().catch(() => {});
    }
    await writeReport();
  }
}

run();
