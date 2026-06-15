# SmartMenu - AI Agent Guide

## Project Overview

**SmartMenu** is an AI-powered restaurant forecasting platform that helps restaurant owners optimize menu preparation, sales forecasting, and waste management through machine learning.

**Architecture**: Multi-tier system with Flutter frontend (web/iOS/Android), FastAPI backend, and PostgreSQL/SQLite database.

**Key Features**:
- Multi-tenant: Each restaurant owner has isolated data
- ML Forecasting: Demand prediction, waste risk classification, profit analysis
- Weather & Calendar Integration: Uses OpenWeather API and Nager.Date for public holidays
- Sales & Analytics: Track dishes, sales, waste with real-time insights
- AI Chat: Context-aware recommendations via Claude AI API
- Firebase Auth: Google/email authentication

---

## Tech Stack

| Layer | Technology | Key Files |
|-------|-----------|-----------|
| **Backend** | Python 3.11+, FastAPI, SQLAlchemy ORM | `backend/main.py`, `backend/routers/` |
| **Frontend** | Flutter 3.11+, Provider state management | `flutter_app/lib/main.dart`, `flutter_app/pubspec.yaml` |
| **Database** | PostgreSQL (prod), SQLite (dev) | See [PRODUCTION_DATABASE.md](docs/PRODUCTION_DATABASE.md) |
| **ML** | scikit-learn (sklearn) | `backend/services/ml_service.py`, `intelligence_service.py` |
| **Auth** | Firebase Admin SDK, Firebase Auth | `backend/routers/auth.py` |

---

## Codebase Structure

### Backend (`backend/`)
```
models/           # SQLAlchemy ORM models for all entities
  ├── user.py     # User, Restaurant
  ├── menu.py     # Category, Dish
  ├── sales.py    # DailySales, SalesItem
  ├── waste.py    # WasteEntry
  └── intelligence.py  # WeatherSnapshot, CalendarEvent, PredictionRecord, InventoryRecipe
routers/          # FastAPI route handlers
  ├── auth.py     # Login, registration, restaurant setup, data export
  ├── menu.py     # Dishes, categories CRUD
  ├── sales.py    # Sales entries and analytics
  ├── waste.py    # Waste tracking
  ├── analytics.py # Historical analytics (profit, demand, classification)
  └── intelligence.py  # Smart dashboard, chat, weather, calendar, training
services/         # Business logic
  ├── ml_service.py          # Demand, profit, classification helpers
  ├── intelligence_service.py # Feature engineering, model training, recommendations
  └── waste_service.py       # Waste analysis
schemas/          # Pydantic models for request/response validation
database.py       # SQLAlchemy engine and session
config.py         # Environment variable loading
main.py          # FastAPI app setup, middleware, router mounting
```

### Frontend (`flutter_app/lib/`)
```
screens/          # Full-page widgets
  ├── login_screen.dart
  ├── home_screen.dart
  └── [feature]_screen.dart (analytics, menu, sales, waste)
providers/        # Provider state management
  ├── restaurant_provider.dart
  ├── analytics_provider.dart
  ├── menu_provider.dart
  ├── sales_provider.dart
  ├── waste_provider.dart
  └── theme_provider.dart
services/         # API communication
  ├── api_service.dart       # HTTP client, auth headers
  └── firebase_options.dart  # Firebase config from .env
config/           # App configuration
  └── theme.dart  # Material Design themes (light/dark)
models/           # Data classes for API responses
widgets/          # Reusable UI components
main.dart         # App entry, auth gate, provider setup
```

---

## Build & Run Commands

### Backend Setup

**1. Install Python dependencies**
```bash
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1  # Windows
source .venv/bin/activate     # macOS/Linux
pip install -r requirements.txt
```

**2. Environment setup (`.env` file in `backend/`)**
```env
# Database
DATABASE_URL=sqlite:///restaurant.db

# Firebase (optional, for auth in dev)
FIREBASE_PROJECT_ID=your-project
FIREBASE_PRIVATE_KEY=...
FIREBASE_CLIENT_EMAIL=...

# Weather API (optional)
WEATHER_PROVIDER=openweathermap
OPENWEATHER_API_KEY=...

# Claude AI (for chat recommendations)
CLAUDE_API_KEY=...

# Debug
DEBUG=False
```

**3. Run backend**
```bash
cd backend
python main.py
# Runs on http://localhost:8000
# Swagger docs: http://localhost:8000/docs
```

**4. Run tests/ML audit**
```bash
cd backend
python test_ml.py  # Verifies ML pipeline end-to-end
```

### Frontend Setup

**1. Environment setup (`.env` file in `flutter_app/`)**
```env
FIREBASE_API_KEY=...
FIREBASE_APP_ID=...
FIREBASE_PROJECT_ID=...
FIREBASE_AUTH_DOMAIN=...
FIREBASE_STORAGE_BUCKET=...
FIREBASE_MESSAGING_SENDER_ID=...
API_BASE_URL=http://localhost:8000  # Backend URL
```

**2. Run Flutter web (development)**
```bash
cd flutter_app
.\run_web.ps1     # Windows
./run_web.ps1     # macOS/Linux with bash
```

**3. Build Flutter web (production)**
```bash
cd flutter_app
.\build_web.ps1
# Output: flutter_app/build/web/
```

---

## Key Architectural Patterns

### 1. **Multi-Tenant Isolation**
- Every endpoint requires `restaurant_id` and validates user ownership via `require_restaurant_owner()`
- Queries always filter by `restaurant_id` to prevent cross-tenant data leaks
- Auth router: [auth.py](backend/routers/auth.py) lines 58-63

### 2. **ML Feature Engineering**
- **Input**: Sales history, weather, calendar, dish metadata
- **Features**: Day-of-week, season, temperature, humidity, rain, weekend flag, event flag, lagged values
- **Models**:
  - **Regression** (LinearRegression): Predict quantity for next day/week
  - **Classification** (DecisionTreeClassifier): Classify waste risk (low/medium/high)
- See [intelligence_service.py](backend/services/intelligence_service.py) lines 38-45 for feature columns

### 3. **Weather & Calendar Multipliers**
- Base prediction adjusted by contextual rules:
  - **Hot items** (chai, tea, coffee): +18% in cold, -12% when hot
  - **Cold items** (juice, lassi): +25% when hot (+32°C)
  - **Non-veg**: +10% on weekends, +20% during Eid/Ramadan
  - See [intelligence_service.py](backend/services/intelligence_service.py#L92-L135)

### 4. **State Management (Flutter)**
- Use `Provider` for reactive updates
- Screens call `provider.loadData()` on init
- Providers fetch from `ApiService`, cache results, notify listeners
- Example: [analytics_provider.dart](flutter_app/lib/providers/analytics_provider.dart)

### 5. **Database Schema Auto-Migration**
- SQLAlchemy creates tables on startup (`Base.metadata.create_all()`)
- Schema updates handled in `ensure_schema_updates()` function
- See [main.py](backend/main.py#L12-L35)

---

## Common Development Tasks

### **Adding a new dish property**
1. Add column to `Dish` model: [models/menu.py](backend/models/menu.py)
2. Add schema field: [schemas/menu.py](backend/schemas/menu.py)
3. Schema auto-migration will add column on next startup
4. Update Flutter model in [flutter_app/lib/models/](flutter_app/lib/models/)

### **Modifying ML model features**
1. Edit `BASE_FEATURE_COLUMNS` or `HISTORY_FEATURE_COLUMNS`: [intelligence_service.py](backend/services/intelligence_service.py#L38-L45)
2. Update `_feature_frame()` to extract/calculate new features: [intelligence_service.py](backend/services/intelligence_service.py#L350+)
3. Test with `python test_ml.py`

### **Adding weather/calendar rules**
- Weather multipliers: [_dish_weather_multiplier()](backend/services/intelligence_service.py#L92-L115)
- Calendar multipliers: [_calendar_multiplier()](backend/services/intelligence_service.py#L118-L135)

### **Implementing new API endpoint**
1. Create router function in `routers/[feature].py`
2. Use `@require_restaurant_owner()` to validate ownership
3. Add Pydantic schema in `schemas/[feature].py`
4. Include router in [main.py](backend/main.py#L40-L45)
5. Call from Flutter via [ApiService.dart](flutter_app/lib/services/api_service.dart)

---

## Important Files Reference

| Task | Location |
|------|----------|
| **Modify restaurant properties** | [models/user.py](backend/models/user.py) → [schemas/user.py](backend/schemas/user.py) → [routers/auth.py](backend/routers/auth.py) |
| **View database schema** | [docs/AI_RESTAURANT_PLATFORM.md](docs/AI_RESTAURANT_PLATFORM.md#2-database-schema) |
| **Understand ML workflow** | [docs/AI_RESTAURANT_PLATFORM.md](docs/AI_RESTAURANT_PLATFORM.md#5-ml-workflow-diagram) & [services/intelligence_service.py](backend/services/intelligence_service.py#L200-L280) |
| **Add analytics calculation** | [services/ml_service.py](backend/services/ml_service.py) → [routers/analytics.py](backend/routers/analytics.py) |
| **Setup Flutter environment** | [flutter_app/README.md](flutter_app/README.md) |
| **Export restaurant data** | [routers/auth.py](backend/routers/auth.py#L133-L180) |
| **View API documentation** | Run backend, visit `http://localhost:8000/docs` (Swagger UI) |

---

## Environment Variables Checklist

### Backend (`backend/.env`)
- `DATABASE_URL` - Connection string (required)
- `FIREBASE_PROJECT_ID`, `FIREBASE_PRIVATE_KEY`, `FIREBASE_CLIENT_EMAIL` - For auth
- `OPENWEATHER_API_KEY` or `WEATHERAPI_KEY` - For weather forecast
- `CLAUDE_API_KEY` - For AI chat recommendations

### Frontend (`flutter_app/.env`)
- `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_PROJECT_ID`, etc. - From Firebase Console
- `API_BASE_URL` - Backend URL (default: `http://localhost:8000`)

---

## Testing

**ML Pipeline Test** (verifies demand, profit, classification, dashboard)
```bash
cd backend
python test_ml.py
```

**Run backend with sample data**
```bash
cd backend
python seed.py  # Creates test restaurant and data
python main.py
```

---

## Debugging Tips

1. **"Restaurant not found"**: Ensure `restaurant_id` in URL/body matches the current user's restaurant
2. **"Invalid token"**: Check Firebase is initialized; token must be valid JWT from Firebase Auth
3. **ML predictions empty**: Ensure sales data exists; run `python seed.py` to generate sample data
4. **Weather returns baseline**: Check `OPENWEATHER_API_KEY` is set and API limit not exceeded
5. **Flutter won't build**: Run `flutter clean` then `flutter pub get`; ensure `.env` has valid Firebase config

---

## Related Documentation

- [AI Restaurant Platform Architecture](docs/AI_RESTAURANT_PLATFORM.md) - Comprehensive design document
- [Production Database Setup](docs/PRODUCTION_DATABASE.md) - PostgreSQL configuration
- [Flutter App Setup](flutter_app/README.md) - Web app build and deployment
