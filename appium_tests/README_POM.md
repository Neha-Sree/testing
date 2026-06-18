# Life Nest Android Appium POM Framework

This is a Node.js Appium 2.x automation framework for the Life Nest Flutter Android app.
It uses WebdriverIO, Mocha, Page Object Model, screenshots, logs, Excel reports, and HTML reports.

## What It Covers

The framework analyzes and automates the main mobile flows already present in the app:

- Entry / splash flow
- Role selection
- Account creation
- Mother onboarding form
- Mother dashboard and tracker features
- Doctor dashboard navigation
- Health Worker dashboard action flow
- Failure screenshots and execution logging

## Folder Structure

```text
appium_tests/
  pages/                 Page Object Model classes
  tests/                 POM E2E test cases
  utils/                 screenshot, logger, HTML report utilities
  reports/
    excel/               Excel reports
    html/                HTML execution reports
  screenshots/           Failure screenshots
  logs/                  Execution logs
  test_data/             Test data templates
  config.js              Appium/device/APK configuration
  run_pom_tests.js       POM suite runner
```

## Prerequisites

- Node.js and npm
- Appium 2.x
- Android SDK platform-tools available on PATH (`adb`)
- Android emulator or USB-connected Android device
- Flutter debug APK built at `build/app/outputs/flutter-apk/app-debug.apk`
- Backend running on `localhost:8000`

For a real USB device, keep the backend reachable with:

```bash
adb reverse tcp:8000 tcp:8000
```

## Install

```bash
cd D:\FlutterApps\my_app\appium_tests
npm install
npm run appium:install-driver
```

## Build App

From the project root:

```bash
cd D:\FlutterApps\my_app
flutter build apk --debug
```

## Start Appium

In terminal 1:

```bash
cd D:\FlutterApps\my_app\appium_tests
npm run appium
```

Leave this terminal open.

## Run POM E2E Suite

In terminal 2:

```bash
cd D:\FlutterApps\my_app\appium_tests
npm run test:pom
```

## Device Configuration

Optional environment variables:

```bash
set DEVICE_UDID=emulator-5554
set APP_PATH=D:\FlutterApps\my_app\build\app\outputs\flutter-apk\app-debug.apk
set APPIUM_HOST=127.0.0.1
set APPIUM_PORT=4723
set NO_RESET=false
```

PowerShell example:

```powershell
$env:DEVICE_UDID="emulator-5554"
npm run test:pom
```

## Reports

After execution:

```text
appium_tests/reports/excel/*.xlsx
appium_tests/reports/html/*.html
appium_tests/screenshots/*.png
appium_tests/logs/*.log
```

The Excel report includes:

- Test case name
- Role
- Pass/fail status
- Execution duration
- Error details
- Step-by-step execution details

The HTML report includes:

- Summary dashboard
- Pass/fail statistics
- Test duration
- Step logs
- Error messages

## Main Command Summary

```bash
cd D:\FlutterApps\my_app
flutter build apk --debug

cd D:\FlutterApps\my_app\appium_tests
npm install
npm run appium
npm run test:pom
```
