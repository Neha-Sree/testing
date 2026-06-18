# Life Nest Mobile - Appium End-to-End Automation

A self-contained mobile test automation project using **Appium** (UiAutomator2) and
**Node.js (WebdriverIO + Mocha)** to perform end-to-end testing of the **Android**
build of the **Life Nest** application.

It mirrors the `selenium_tests/` web suite: it drives the three user roles
(Mother, Doctor, Health Worker) through real device interactions, logs every
step, and compiles the results into a styled Excel report.

---

## Folder Structure

```
appium_tests/
├── config.js             # Appium server + Android capabilities + report path
├── helpers.js            # WebdriverIO driver build, step logger, AppHelper API
├── report_generator.js   # ExcelJS generator for the styled spreadsheet
├── test_e2e.js           # Mocha tests containing the end-to-end journeys
├── run_tests.js          # Orchestrates Mocha + Excel report generation
├── package.json          # Dependencies and scripts
└── README.md             # This file
```

---

## Prerequisites

1. **Node.js & npm** installed.
2. **Java JDK 17** + **Android SDK** (`adb`, platform-tools) installed and on `PATH`.
3. **A running Android emulator or a USB-connected device** with USB debugging on.
   - Verify with: `adb devices` (the device must show as `device`, not `unauthorized`).
4. **The Life Nest backend** running (see `../backend`), reachable from the device.
5. **A built debug APK** of the app (steps below).

> Flutter widgets are surfaced to Appium through Android's accessibility tree, so
> selectors resolve against each widget's `text` / `content-desc`.

---

## Setup

1. Install dependencies (Appium server + UiAutomator2 driver are local devDeps):
   ```bash
   cd appium_tests
   npm install
   ```
2. Install the UiAutomator2 driver into the Appium install (first run only):
   ```bash
   npm run appium:install-driver
   ```
3. (Optional) Verify your environment is ready:
   ```bash
   npm run appium:doctor
   ```

---

## Build the App Under Test

From the project root, build a debug APK:

```bash
flutter build apk --debug
```

This produces `build/app/outputs/flutter-apk/app-debug.apk`, which `config.js`
points to by default. To test an already-installed build instead, set
`NO_RESET=true` and omit `APP_PATH`.

---

## Running the Tests

1. Start the Appium server in one terminal:
   ```bash
   cd appium_tests
   npm run appium
   ```
   (Leave it running. Default URL: `http://127.0.0.1:4723`.)

2. In a second terminal, run the suite + report generator:
   ```bash
   cd appium_tests
   npm test
   ```

### Configuration via Environment Variables

| Variable           | Purpose                                            | Default                                              |
| ------------------ | -------------------------------------------------- | ---------------------------------------------------- |
| `APPIUM_HOST`      | Appium server host                                 | `127.0.0.1`                                          |
| `APPIUM_PORT`      | Appium server port                                 | `4723`                                               |
| `DEVICE_UDID`      | Target a specific device (`adb devices`)           | first online device                                  |
| `PLATFORM_VERSION` | Android version of the device                       | auto                                                 |
| `APP_PATH`         | Path to the APK to install                          | `../build/app/outputs/flutter-apk/app-debug.apk`     |
| `APP_PACKAGE`      | App package id                                      | `com.example.my_app`                                 |
| `APP_ACTIVITY`     | Launch activity                                     | `com.example.my_app.MainActivity`                    |
| `NO_RESET`         | Don't reinstall/clear app between sessions          | `false`                                              |
| `TIMEOUT`          | Default element wait (ms)                           | `15000`                                              |
| `REPORT_PATH`      | Output Excel path                                   | `./test_report.xlsx`                                 |

Example (Windows PowerShell):
```powershell
$env:DEVICE_UDID="emulator-5554"; npm test
```

---

## The Excel Report

After execution, `test_report.xlsx` is written into this folder.

### Tab 1 — Summary Dashboard
Total / passed / failed cases, overall pass rate, total duration, and the mobile
platform context (Appium engine, app package, device, runner).

### Tab 2 — Execution Details
A chronological, step-by-step log per test case with individual step statuses
(Passed / Failed / Warning), timings, and full error details for any failures.

---

## Notes & Troubleshooting

- **No device found**: ensure `adb devices` lists exactly one authorized device.
- **Elements not found**: Flutter must have rendered the semantics tree. The helper
  waits out the 3s splash; increase `SPLASH_WAIT` if your device is slow.
- **Keyboard covers fields**: the helper auto-hides the keyboard after typing.
- **First launch is slow**: UiAutomator2 server install + APK install adds time on
  the first session; subsequent runs with `NO_RESET=true` are faster.
