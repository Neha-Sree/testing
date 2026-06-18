const fs = require('fs');
const path = require('path');

const reportsDir = path.join(__dirname, '..', 'reports', 'html');

function escapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function generateHtmlReport(testRuns) {
  if (!fs.existsSync(reportsDir)) {
    fs.mkdirSync(reportsDir, { recursive: true });
  }

  const total = testRuns.length;
  const passed = testRuns.filter((run) => run.status === 'Passed').length;
  const failed = total - passed;
  const passRate = total ? Math.round((passed / total) * 100) : 0;

  const rows = testRuns.map((run, index) => {
    const steps = (run.steps || [])
      .map((step) => `<li><strong>${escapeHtml(step.status)}</strong> ${escapeHtml(step.timestamp)} - ${escapeHtml(step.description)}</li>`)
      .join('');
    const statusClass = run.status === 'Passed' ? 'pass' : 'fail';
    return `
      <tr>
        <td>APP-${String(index + 1).padStart(3, '0')}</td>
        <td>${escapeHtml(run.name)}</td>
        <td>${escapeHtml(run.role)}</td>
        <td class="${statusClass}">${escapeHtml(run.status)}</td>
        <td>${escapeHtml(run.duration)}s</td>
        <td>${escapeHtml(run.error || '')}</td>
      </tr>
      <tr><td colspan="6"><ul>${steps}</ul></td></tr>
    `;
  }).join('');

  const html = `<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <title>Life Nest Appium E2E Report</title>
  <style>
    body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; color: #222; }
    h1 { color: #ad1457; }
    .cards { display: flex; gap: 12px; margin: 16px 0; }
    .card { border: 1px solid #ddd; border-radius: 8px; padding: 12px 18px; min-width: 140px; background: #fff5f8; }
    .card strong { display: block; font-size: 22px; }
    table { border-collapse: collapse; width: 100%; margin-top: 16px; }
    th, td { border: 1px solid #ddd; padding: 8px; vertical-align: top; }
    th { background: #f8bbd0; color: #4a148c; }
    .pass { color: #2e7d32; font-weight: bold; }
    .fail { color: #c62828; font-weight: bold; }
    ul { margin: 4px 0 4px 20px; }
  </style>
</head>
<body>
  <h1>Life Nest Mobile Appium E2E Report</h1>
  <p>Generated: ${escapeHtml(new Date().toLocaleString())}</p>
  <div class="cards">
    <div class="card">Total<strong>${total}</strong></div>
    <div class="card">Passed<strong>${passed}</strong></div>
    <div class="card">Failed<strong>${failed}</strong></div>
    <div class="card">Pass Rate<strong>${passRate}%</strong></div>
  </div>
  <table>
    <thead>
      <tr><th>Test Case ID</th><th>Testcase Name</th><th>Role</th><th>Status</th><th>Duration</th><th>Error</th></tr>
    </thead>
    <tbody>${rows}</tbody>
  </table>
</body>
</html>`;

  const reportPath = path.join(reportsDir, `appium_report_${Date.now()}.html`);
  fs.writeFileSync(reportPath, html);
  return reportPath;
}

module.exports = {
  generateHtmlReport
};
