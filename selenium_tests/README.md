# Life Nest Web - Selenium End-to-End Automation

A self-contained web test automation project using **Selenium WebDriver** and **Node.js** to perform end-to-end testing for the Web version of the **Life Nest** application.

It simulates user interactions across three roles (Mother, Doctor, Health Worker), logs step-by-step outcomes, and compiles them into a professionally designed Excel report.

---

## Folder Structure

```
selenium_tests/
├── config.js             # General configuration (URL, browser, timeout)
├── helpers.js            # Selenium wrapper helpers and step log accumulator
├── report_generator.js   # ExcelJS generator to build styled spreadsheets
├── test_e2e.js           # Mocha tests containing end-to-end journeys
├── run_tests.js          # Main program runner orchestrating Mocha and Reporting
├── package.json          # Dependencies and script commands
└── README.md             # This documentation file
```

---

## Prerequisites

1. **Node.js & npm** installed.
2. **Google Chrome** browser installed.
3. **Flutter SDK** installed (to compile and serve the web app).

---

## Quick Setup & Installation

1. Navigate to the `selenium_tests` directory:
   ```bash
   cd selenium_tests
   ```
2. Install npm dependencies:
   ```bash
   npm install
   ```

---

## How to Prepare and Run the Application

Before running the automated test suite, ensure both the backend service and the Flutter Web application are running:

### Step 1: Run the Backend Service
The web application depends on the FastAPI Python backend. Start it by running:
```bash
# Navigate to the backend directory
cd backend

# Activate your virtual environment and start the uvicorn server
python run.py
```
*Note: Make sure the server runs on port 8000 (default).*

### Step 2: Build & Run the Flutter Web Application
For Selenium to find buttons and text boxes reliably, we strongly recommend building the Flutter application with the **HTML web renderer**.

Execute the following commands from the root directory:
```bash
# Compile Flutter Web using the HTML renderer (highly recommended for Selenium element resolution)
flutter build web --web-renderer html

# Start a local web server to serve the build (port 8080 by default)
npx http-server build/web -p 8080
```

---

## How to Execute the Selenium Tests

Once the web application is running at `http://localhost:8080`, start the testing process:

```bash
# Navigate to the selenium_tests folder
cd selenium_tests

# Execute the runner script
node run_tests.js
```

### Custom Configurations (Environment Variables)

You can pass environment variables to configure the execution dynamically:
- `BASE_URL`: Override the web application URL (default: `http://localhost:8080`).
- `HEADLESS`: Run the browser in headless mode without UI (options: `true` or `false`, default: `false`).
- `BROWSER`: Run on a different browser (default: `chrome`).

*Example:*
```bash
$env:HEADLESS="true"; node run_tests.js
```

---

## Analyzing the Excel Report

After test execution, the engine automatically creates a styled spreadsheet `test_report.xlsx` inside the `selenium_tests` directory.

### Tab 1: Summary Dashboard
A clean executive dashboard containing:
- **Test Metric Table**: Total cases, passed cases, failed cases, and overall Pass Rate %.
- **Platform Context**: Environment, browser, headless flag, and timestamps.
- **Visual Design**: Themed headers and status boxes (Green for 100% Pass, Red for failure).

### Tab 2: Execution Details
A full, chronological breakdown containing:
- **Test Case Name & Role** groupings.
- **Step-by-step logs** (e.g. "Input Age: 27", "Select AB+ from the dropdown").
- **Individual step statuses** and overall test durations.
- **Failures & Errors** highlighted in Red with exact driver error details.
