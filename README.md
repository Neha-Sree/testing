# my_app

A new Flutter project.

## Mom onboarding backend (Python + SQL)

This app now posts mom onboarding data to a Python backend with SQL storage.
It now includes optional due date and pregnant weeks fields.

### 1) Start backend

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Data is stored in `backend/mothers.db` and uploaded images are saved in `backend/uploads/`.

### 2) Start Flutter app with backend URL

Android emulator can use default `http://10.0.2.2:8000`.

For physical devices or different hosts, provide:

```bash
flutter run --dart-define=MOM_API_BASE_URL=http://<YOUR_IP>:8000
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
