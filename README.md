# OptiFit

OptiFit is a Flutter mobile application backed by FastAPI. It generates meal
recommendations, workout routines and rule-based Progressive Overload targets,
then stores the current profile and selected recommendation history in SQLite.

## Project structure

- `lib/`: Flutter presentation, API communication and local persistence.
- `backend/`: FastAPI routes, dataset preprocessing and recommendation logic.
- `backend/data/`: read-only food and exercise datasets used by FastAPI.
- `test/`: Flutter widget and service tests.
- `backend/tests/`: Python unit and API tests.

## Prerequisites

- Flutter with a compatible Android SDK.
- Python 3.11 or newer.

## Start the backend

Run these commands from the project root:

```powershell
python -m venv backend\.venv
backend\.venv\Scripts\python -m pip install -r backend\requirements-dev.txt
backend\.venv\Scripts\python -m uvicorn backend.main:app --reload
```

The health endpoint is available at `http://127.0.0.1:8000/api/health`.

## Run the Flutter application

For the Android emulator, the default API address is already
`http://10.0.2.2:8000`:

```powershell
flutter pub get
flutter run
```

For a physical Android device, supply the computer's LAN address:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

The phone and computer must be connected to the same network, and the backend
port must be allowed through the local firewall.

## Verification

```powershell
flutter analyze
flutter test
python -m unittest discover -s backend\tests -v
```

## Deployment note

The included `render.yaml` deploys the FastAPI backend as a Render Web Service:

1. Push the repository to GitHub.
2. In Render, select **New > Blueprint** and connect this repository.
3. Deploy the `optifit-api` service using the Free plan.
4. Verify `https://<service-name>.onrender.com/api/health`.
5. Build Android with the deployed HTTPS URL:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://<service-name>.onrender.com
```

Render Free services sleep after a period of inactivity. The first request after
sleep may take longer while the service starts again. Before a demonstration,
open the health endpoint and wait until it returns `"status": "ok"`.

The current API has no private user accounts and stores no user history on the
server. Before production use, restrict CORS origins, add authentication and
apply request-rate limits.
