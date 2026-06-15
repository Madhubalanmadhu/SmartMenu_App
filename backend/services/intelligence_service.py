import json
import os
from collections import defaultdict
from datetime import date, timedelta

import httpx
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.ensemble import RandomForestRegressor
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error
from sklearn.tree import DecisionTreeClassifier
from sqlalchemy.orm import Session

from models.intelligence import CalendarEvent, InventoryRecipe, PredictionRecord, WeatherSnapshot
from models.menu import Dish
from models.sales import DailySales, SalesItem
from models.user import Restaurant
from models.waste import WasteEntry
from services.ml_service import _prediction_margin, _unit_ingredient_cost, predict_demand


HOT_KEYWORDS = ("chai", "tea", "coffee", "soup", "rasam")
COLD_KEYWORDS = ("juice", "watermelon", "cold", "lassi", "ice", "drink")
NON_VEG_KEYWORDS = ("chicken", "mutton", "fish", "egg", "biryani")


BASE_FEATURE_COLUMNS = [
    "dish_id",
    "category_id",
    "day_of_week",
    "is_weekend",
    "month",
    "season",
    "temperature",
    "humidity",
    "rain_probability",
    "has_event",
]

HISTORY_FEATURE_COLUMNS = [
    "lag_1",
    "lag_7",
    "rolling_7",
    "rolling_14",
    "dish_recent_avg",
]

MODEL_FEATURE_COLUMNS = BASE_FEATURE_COLUMNS + HISTORY_FEATURE_COLUMNS


def _season(month: int) -> int:
    if month in (3, 4, 5):
        return 1
    if month in (6, 7, 8, 9):
        return 2
    if month in (10, 11):
        return 3
    return 4


def _safe_int(value) -> int:
    if value is None or not np.isfinite(value):
        return 0
    return max(0, int(round(value)))


def _dish_category_name(dish: Dish) -> str:
    category = getattr(dish, "category", None)
    return (getattr(category, "name", "") or "").lower()


def _dish_weather_multiplier(dish: Dish, weather: dict) -> float:
    name = dish.name.lower()
    category = _dish_category_name(dish)
    condition = str(weather.get("condition", "")).lower()
    temperature = float(weather.get("temperature", 0) or 0)
    rain = float(weather.get("rain_probability", 0) or 0)
    multiplier = 1.0

    if rain >= 50 or "rain" in condition:
        multiplier *= 0.9
        if any(word in name for word in HOT_KEYWORDS):
            multiplier *= 1.18
        if "starter" in category or "snack" in category:
            multiplier *= 1.08

    if temperature >= 32:
        if any(word in name for word in COLD_KEYWORDS) or "beverage" in category:
            multiplier *= 1.25
        if any(word in name for word in HOT_KEYWORDS):
            multiplier *= 0.88

    if temperature <= 18 and any(word in name for word in HOT_KEYWORDS):
        multiplier *= 1.18

    return multiplier


def _calendar_multiplier(dish: Dish, target_date: date, events: list[CalendarEvent]) -> float:
    name = dish.name.lower()
    multiplier = 1.0
    if target_date.weekday() >= 5:
        multiplier *= 1.12
        if any(word in name for word in NON_VEG_KEYWORDS):
            multiplier *= 1.1

    event_names = " ".join(event.name.lower() for event in events)
    if event_names:
        multiplier *= 1.08
    if "diwali" in event_names or "christmas" in event_names:
        if "dessert" in _dish_category_name(dish) or any(word in name for word in ("sweet", "gulfi", "ras")):
            multiplier *= 1.25
    if "ramadan" in event_names or "eid" in event_names:
        if any(word in name for word in NON_VEG_KEYWORDS):
            multiplier *= 1.2

    return multiplier


def _default_weather(target_date: date) -> dict:
    return {
        "forecast_date": target_date.isoformat(),
        "temperature": 28,
        "humidity": 60,
        "rain_probability": 0,
        "condition": "baseline",
        "wind_speed": 0,
        "source": "baseline",
    }


def _weather_fallback(target_date: date, source: str, detail: str | None = None) -> dict:
    weather = _default_weather(target_date)
    weather["source"] = source
    if detail:
        weather["condition"] = detail[:120]
    return weather


def get_weather_for_date(restaurant_id: int, target_date: date, db: Session) -> dict:
    snapshot = (
        db.query(WeatherSnapshot)
        .filter(
            WeatherSnapshot.restaurant_id == restaurant_id,
            WeatherSnapshot.forecast_date == target_date,
        )
        .first()
    )
    if not snapshot:
        return _default_weather(target_date)

    return {
        "forecast_date": snapshot.forecast_date.isoformat(),
        "temperature": snapshot.temperature or 0,
        "humidity": snapshot.humidity or 0,
        "rain_probability": snapshot.rain_probability or 0,
        "condition": snapshot.condition or "",
        "wind_speed": snapshot.wind_speed or 0,
        "source": snapshot.source or "stored",
    }


def _live_weather_configured() -> bool:
    provider = os.getenv("WEATHER_PROVIDER", "openweathermap").lower()
    if provider == "weatherapi":
        return bool(os.getenv("WEATHERAPI_KEY"))
    return bool(os.getenv("OPENWEATHER_API_KEY"))


def _weather_city_for_restaurant(restaurant_id: int, db: Session) -> str | None:
    configured_city = os.getenv("WEATHER_CITY") or os.getenv("DEFAULT_WEATHER_CITY")
    if configured_city and configured_city.strip():
        return configured_city.strip()

    restaurant = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
    if not restaurant:
        return None

    saved_city = (getattr(restaurant, "weather_city", "") or "").strip()
    if saved_city:
        return saved_city

    address = (restaurant.address or "").strip()
    if not address:
        return None

    parts = [part.strip() for part in address.split(",") if part.strip()]
    if len(parts) >= 3:
        return parts[-3]
    if len(parts) >= 2:
        return parts[-2]
    return address


def set_weather_city(restaurant_id: int, city: str, db: Session) -> str:
    cleaned_city = city.strip()
    if not cleaned_city:
        raise ValueError("City is required")

    restaurant = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
    if not restaurant:
        raise ValueError("Restaurant not found")

    restaurant.weather_city = cleaned_city
    db.commit()
    return cleaned_city


def _calendar_country_for_restaurant(restaurant_id: int, db: Session) -> str:
    configured_country = os.getenv("CALENDAR_COUNTRY_CODE")
    if configured_country and configured_country.strip():
        return configured_country.strip().upper()

    restaurant = db.query(Restaurant).filter(Restaurant.id == restaurant_id).first()
    if not restaurant:
        return "IN"

    country_code = (getattr(restaurant, "country_code", "") or "").strip()
    return country_code.upper() if country_code else "IN"


async def ensure_live_intelligence_context(
    restaurant_id: int,
    db: Session,
    target_date: date | None = None,
) -> dict:
    target_date = target_date or (date.today() + timedelta(days=1))
    result: dict = {
        "weather": "baseline",
        "calendar": "unchanged",
        "weather_city": None,
    }

    city = _weather_city_for_restaurant(restaurant_id, db)
    result["weather_city"] = city
    if city and _live_weather_configured():
        weather = await refresh_weather(restaurant_id, city, db, target_date)
        result["weather"] = weather.get("source", "updated")

    country_code = _calendar_country_for_restaurant(restaurant_id, db)
    has_holidays = (
        db.query(CalendarEvent)
        .filter(
            CalendarEvent.source == "nager.date",
            CalendarEvent.country_code == country_code,
            CalendarEvent.event_date >= date(target_date.year, 1, 1),
            CalendarEvent.event_date <= date(target_date.year, 12, 31),
        )
        .first()
        is not None
    )
    if not has_holidays:
        events = await refresh_public_holidays(country_code, target_date.year, db)
        result["calendar"] = f"refreshed_{len(events)}"

    return result


async def refresh_weather(
    restaurant_id: int,
    city: str,
    db: Session,
    target_date: date | None = None,
) -> dict:
    target_date = target_date or (date.today() + timedelta(days=1))
    provider = os.getenv("WEATHER_PROVIDER", "openweathermap").lower()

    if provider == "weatherapi":
        api_key = os.getenv("WEATHERAPI_KEY")
        if not api_key:
            return _default_weather(target_date)
        url = "https://api.weatherapi.com/v1/forecast.json"
        params = {"key": api_key, "q": city, "days": 2, "aqi": "no", "alerts": "no"}
        try:
            async with httpx.AsyncClient(timeout=12) as client:
                response = await client.get(url, params=params)
                response.raise_for_status()
                data = response.json()
            day = data["forecast"]["forecastday"][-1]["day"]
        except (httpx.HTTPError, KeyError, IndexError, TypeError, ValueError) as exc:
            weather = _weather_fallback(target_date, "weatherapi_unavailable", f"Weather unavailable for {city}")
            upsert_weather(restaurant_id, weather, db)
            return weather
        weather = {
            "forecast_date": target_date.isoformat(),
            "temperature": day.get("avgtemp_c", 0),
            "humidity": day.get("avghumidity", 0),
            "rain_probability": day.get("daily_chance_of_rain", 0),
            "condition": day.get("condition", {}).get("text", ""),
            "wind_speed": day.get("maxwind_kph", 0),
            "source": "weatherapi",
        }
    else:
        api_key = os.getenv("OPENWEATHER_API_KEY")
        if not api_key:
            return _default_weather(target_date)
        url = "https://api.openweathermap.org/data/2.5/forecast"
        params = {"q": city, "appid": api_key, "units": "metric"}
        try:
            async with httpx.AsyncClient(timeout=12) as client:
                response = await client.get(url, params=params)
                response.raise_for_status()
                data = response.json()
        except httpx.HTTPError as exc:
            weather = _weather_fallback(target_date, "openweathermap_unavailable", f"Weather unavailable for {city}")
            upsert_weather(restaurant_id, weather, db)
            return weather
        forecasts = data.get("list", [])
        chosen = forecasts[min(7, len(forecasts) - 1)] if forecasts else {}
        main = chosen.get("main", {})
        weather_info = (chosen.get("weather") or [{}])[0]
        weather = {
            "forecast_date": target_date.isoformat(),
            "temperature": main.get("temp", 0),
            "humidity": main.get("humidity", 0),
            "rain_probability": round(float(chosen.get("pop", 0) or 0) * 100, 1),
            "condition": weather_info.get("description", ""),
            "wind_speed": chosen.get("wind", {}).get("speed", 0),
            "source": "openweathermap",
        }

    upsert_weather(restaurant_id, weather, db)
    return weather


def upsert_weather(restaurant_id: int, weather: dict, db: Session) -> WeatherSnapshot:
    forecast_date = weather.get("forecast_date")
    if isinstance(forecast_date, str):
        forecast_date = date.fromisoformat(forecast_date)

    snapshot = (
        db.query(WeatherSnapshot)
        .filter(
            WeatherSnapshot.restaurant_id == restaurant_id,
            WeatherSnapshot.forecast_date == forecast_date,
        )
        .first()
    )
    if not snapshot:
        snapshot = WeatherSnapshot(restaurant_id=restaurant_id, forecast_date=forecast_date)
        db.add(snapshot)

    snapshot.temperature = weather.get("temperature", 0)
    snapshot.humidity = weather.get("humidity", 0)
    snapshot.rain_probability = weather.get("rain_probability", 0)
    snapshot.condition = weather.get("condition", "")
    snapshot.wind_speed = weather.get("wind_speed", 0)
    snapshot.source = weather.get("source", "manual")
    db.commit()
    db.refresh(snapshot)
    return snapshot


async def refresh_public_holidays(country_code: str, year: int, db: Session) -> list[dict]:
    country_code = country_code.strip().upper()
    url = f"https://date.nager.at/api/v3/PublicHolidays/{year}/{country_code}"
    try:
        async with httpx.AsyncClient(timeout=12) as client:
            response = await client.get(url)
            response.raise_for_status()
            data = response.json()
    except (httpx.HTTPError, ValueError):
        return []

    saved = []
    for item in data:
        event_date = date.fromisoformat(item["date"])
        event = (
            db.query(CalendarEvent)
            .filter(
                CalendarEvent.event_date == event_date,
                CalendarEvent.name == item["localName"],
                CalendarEvent.country_code == country_code,
            )
            .first()
        )
        if not event:
            event = CalendarEvent(
                event_date=event_date,
                name=item["localName"],
                event_type="public_holiday",
                is_public_holiday=True,
                source="nager.date",
                country_code=country_code,
            )
            db.add(event)
        saved.append({"date": item["date"], "name": item["localName"]})
    db.commit()
    return saved


def get_calendar_context(restaurant_id: int, target_date: date, db: Session) -> dict:
    country_code = _calendar_country_for_restaurant(restaurant_id, db)
    events = (
        db.query(CalendarEvent)
        .filter(
            CalendarEvent.event_date == target_date,
            (CalendarEvent.restaurant_id == restaurant_id)
            | (
                CalendarEvent.restaurant_id.is_(None)
                & (
                    (CalendarEvent.country_code == country_code)
                    | (CalendarEvent.country_code == "")
                )
            ),
        )
        .all()
    )
    return {
        "date": target_date.isoformat(),
        "day_of_week": target_date.strftime("%A"),
        "is_weekend": target_date.weekday() >= 5,
        "season": _season(target_date.month),
        "events": [
            {
                "name": event.name,
                "type": event.event_type,
                "is_public_holiday": event.is_public_holiday,
                "source": event.source,
            }
            for event in events
        ],
    }


def _daily_sales_frame(restaurant_id: int, db: Session) -> pd.DataFrame:
    sales = db.query(DailySales).filter(DailySales.restaurant_id == restaurant_id).all()
    rows = []
    for sale in sales:
        for item in sale.sales_items:
            rows.append(
                {
                "date": sale.sale_date,
                "dish_id": item.dish_id,
                "quantity": item.quantity_sold or 0,
                    "revenue": item.revenue or 0,
                }
            )
    return pd.DataFrame(rows, columns=["date", "dish_id", "quantity", "revenue"])


def _feature_frame(restaurant_id: int, db: Session) -> pd.DataFrame:
    df = _daily_sales_frame(restaurant_id, db)
    if df.empty:
        return df

    dishes = {dish.id: dish for dish in db.query(Dish).filter(Dish.restaurant_id == restaurant_id).all()}
    rows = []
    for _, row in df.iterrows():
        sale_date = row["date"]
        dish = dishes.get(int(row["dish_id"]))
        if not dish:
            continue
        weather = get_weather_for_date(restaurant_id, sale_date, db)
        calendar = get_calendar_context(restaurant_id, sale_date, db)
        rows.append(
            {
                "date": sale_date,
                "dish_id": dish.id,
                "category_id": dish.category_id or 0,
                "day_of_week": sale_date.weekday(),
                "is_weekend": int(sale_date.weekday() >= 5),
                "month": sale_date.month,
                "season": _season(sale_date.month),
                "temperature": weather["temperature"],
                "humidity": weather["humidity"],
                "rain_probability": weather["rain_probability"],
                "has_event": int(bool(calendar["events"])),
                "quantity": row["quantity"],
                "revenue": row["revenue"],
            }
        )
    return pd.DataFrame(rows)


def _prepare_model_frame(df: pd.DataFrame) -> pd.DataFrame:
    if df.empty:
        return df

    frame = df.copy()
    frame["date"] = pd.to_datetime(frame["date"])
    frame = frame.sort_values(["dish_id", "date"]).reset_index(drop=True)
    grouped = frame.groupby("dish_id")["quantity"]
    frame["lag_1"] = grouped.shift(1)
    frame["lag_7"] = grouped.shift(7)
    frame["rolling_7"] = grouped.transform(
        lambda values: values.shift(1).rolling(7, min_periods=1).mean()
    )
    frame["rolling_14"] = grouped.transform(
        lambda values: values.shift(1).rolling(14, min_periods=1).mean()
    )
    frame["dish_recent_avg"] = grouped.transform(
        lambda values: values.shift(1).expanding(min_periods=1).mean()
    )
    for column in MODEL_FEATURE_COLUMNS + ["quantity"]:
        if column not in frame:
            frame[column] = 0
        frame[column] = pd.to_numeric(frame[column], errors="coerce").fillna(0)
    return frame


def _regression_mape(actual, predicted) -> float | None:
    actual_series = pd.Series(np.asarray(actual, dtype=float))
    predicted_series = pd.Series(np.asarray(predicted, dtype=float))
    non_zero = actual_series.replace(0, np.nan)
    values = (np.abs(actual_series - predicted_series) / non_zero).replace(
        [np.inf, -np.inf], np.nan
    ).dropna()
    if values.empty:
        return None
    return float(values.mean() * 100)


def _weighted_recent_quantity(values, day_values=None) -> float:
    history = [float(value) for value in values if pd.notna(value)]
    if not history:
        return 0.0

    recent_7 = float(np.mean(history[-7:]))
    recent_14 = float(np.mean(history[-14:]))
    full_avg = float(np.mean(history))
    weekday_avg = (
        float(np.mean([float(value) for value in day_values if pd.notna(value)]))
        if day_values is not None and len(day_values) > 0
        else recent_7
    )
    trend = 0.0
    if len(history) >= 14:
        trend = recent_7 - float(np.mean(history[-14:-7]))
    elif len(history) >= 4:
        split = max(1, len(history) // 2)
        trend = recent_7 - float(np.mean(history[:split]))

    trend_weight = 0.30 if trend > 0 else 0.12
    forecast = (
        recent_7 * 0.42
        + recent_14 * 0.22
        + full_avg * 0.12
        + weekday_avg * 0.12
        + trend * trend_weight
    )
    return max(0.0, forecast)


def _recent_baseline_predictions(train_df: pd.DataFrame, test_df: pd.DataFrame) -> np.ndarray:
    overall = _weighted_recent_quantity(train_df["quantity"].tolist()) if not train_df.empty else 0.0
    return np.array(
        [
            _weighted_recent_quantity(
                train_df[train_df["dish_id"] == row["dish_id"]]["quantity"].tolist(),
                train_df[
                    (train_df["dish_id"] == row["dish_id"])
                    & (train_df["day_of_week"] == row["day_of_week"])
                ]["quantity"].tolist(),
            )
            or overall
            for _, row in test_df.iterrows()
        ]
    )


def _fit_regression_models(train_df: pd.DataFrame) -> dict[str, object]:
    return {
        "linear_regression": LinearRegression().fit(
            train_df[MODEL_FEATURE_COLUMNS],
            train_df["quantity"],
        ),
        "random_forest": RandomForestRegressor(
            n_estimators=220,
            random_state=42,
            min_samples_leaf=2,
            max_depth=10,
        ).fit(train_df[MODEL_FEATURE_COLUMNS], train_df["quantity"]),
    }


def _evaluate_regression_models(frame: pd.DataFrame) -> dict:
    if frame.empty or len(frame) < 8:
        return {
            "best_model": "recent_baseline",
            "evaluation_method": "insufficient_data_baseline",
            "train_rows": len(frame),
            "test_rows": 0,
            "candidates": {},
            "best_mae": None,
            "best_mape": None,
        }

    sorted_frame = frame.sort_values("date").reset_index(drop=True)
    if len(sorted_frame) >= 20:
        split_index = max(1, int(len(sorted_frame) * 0.8))
        if split_index >= len(sorted_frame):
            split_index = len(sorted_frame) - 1
        train_df = sorted_frame.iloc[:split_index].copy()
        test_df = sorted_frame.iloc[split_index:].copy()
        evaluation_method = "time_ordered_holdout"
    else:
        train_df = sorted_frame.copy()
        test_df = sorted_frame.copy()
        evaluation_method = "in_sample_small_dataset"

    candidates: dict[str, dict] = {}
    baseline_predictions = _recent_baseline_predictions(train_df, test_df)
    candidates["recent_baseline"] = {
        "mae": round(float(mean_absolute_error(test_df["quantity"], baseline_predictions)), 2),
        "mape": (
            round(_regression_mape(test_df["quantity"], baseline_predictions), 2)
            if _regression_mape(test_df["quantity"], baseline_predictions) is not None
            else None
        ),
    }

    if len(train_df) >= 8:
        for name, model in _fit_regression_models(train_df).items():
            predictions = np.clip(model.predict(test_df[MODEL_FEATURE_COLUMNS]), 0, None)
            mape = _regression_mape(test_df["quantity"], predictions)
            candidates[name] = {
                "mae": round(float(mean_absolute_error(test_df["quantity"], predictions)), 2),
                "mape": round(mape, 2) if mape is not None else None,
            }

    best_model = min(candidates, key=lambda name: candidates[name]["mae"])
    return {
        "best_model": best_model,
        "evaluation_method": evaluation_method,
        "train_rows": len(train_df),
        "test_rows": 0 if evaluation_method == "in_sample_small_dataset" else len(test_df),
        "candidates": candidates,
        "best_mae": candidates[best_model]["mae"],
        "best_mape": candidates[best_model]["mape"],
    }


def _train_best_quantity_model(frame: pd.DataFrame) -> tuple[str, object | None]:
    evaluation = _evaluate_regression_models(frame)
    best_model = evaluation["best_model"]
    if best_model == "recent_baseline" or len(frame) < 8:
        return best_model, None
    models = _fit_regression_models(frame)
    return best_model, models[best_model]


def _quantity_model_context(restaurant_id: int, db: Session) -> dict | None:
    df = _prepare_model_frame(_feature_frame(restaurant_id, db))
    if df.empty or len(df) < 8:
        return None
    model_name, model = _train_best_quantity_model(df)
    return {
        "frame": df,
        "model_name": model_name,
        "model": model,
    }


def _future_history_features(frame: pd.DataFrame, dish: Dish) -> dict:
    dish_rows = frame[frame["dish_id"] == dish.id].sort_values("date")
    history = dish_rows["quantity"].astype(float).tolist()
    if not history:
        return {
            "lag_1": 0,
            "lag_7": 0,
            "rolling_7": 0,
            "rolling_14": 0,
            "dish_recent_avg": 0,
        }
    recent_avg = float(np.mean(history[-7:]))
    medium_avg = float(np.mean(history[-14:]))
    recent_weighted_avg = _weighted_recent_quantity(history)
    return {
        "lag_1": history[-1],
        "lag_7": history[-7] if len(history) >= 7 else recent_avg,
        "rolling_7": recent_avg,
        "rolling_14": medium_avg,
        "dish_recent_avg": recent_weighted_avg,
    }


def train_model_report(restaurant_id: int, db: Session) -> dict:
    raw_df = _feature_frame(restaurant_id, db)
    df = _prepare_model_frame(raw_df)
    if df.empty or len(df) < 8:
        return {
            "status": "insufficient_data",
            "regression": "recent/category baseline",
            "classifier": "rule based",
            "rows": len(df),
        }

    evaluation = _evaluate_regression_models(df)
    feature_columns = MODEL_FEATURE_COLUMNS
    X = df[feature_columns]
    y = df["quantity"]
    df_sorted = df.sort_values("date").reset_index(drop=True)
    if len(df_sorted) >= 20:
        split_index = max(1, int(len(df_sorted) * 0.8))
        if split_index >= len(df_sorted):
            split_index = len(df_sorted) - 1
        train_df = df_sorted.iloc[:split_index]
        test_df = df_sorted.iloc[split_index:]
    else:
        train_df = df_sorted
        test_df = df_sorted

    waste_labels = np.where(df["quantity"] <= df["quantity"].median() * 0.6, "high", "low")
    if len(df_sorted) >= 20:
        train_labels = np.where(train_df["quantity"] <= train_df["quantity"].median() * 0.6, "high", "low")
        test_labels = np.where(test_df["quantity"] <= train_df["quantity"].median() * 0.6, "high", "low")
        classifier_candidates = {
            "majority_baseline": float(np.mean(test_labels == pd.Series(train_labels).mode().iloc[0])),
        }
        for name, candidate in {
            "decision_tree": DecisionTreeClassifier(max_depth=4, random_state=42),
            "random_forest_classifier": RandomForestClassifier(
                n_estimators=180,
                random_state=42,
                min_samples_leaf=2,
                max_depth=10,
            ),
        }.items():
            candidate.fit(train_df[feature_columns], train_labels)
            classifier_candidates[name] = float(candidate.score(test_df[feature_columns], test_labels))
        best_classifier = max(
            classifier_candidates,
            key=lambda name: (classifier_candidates[name], name != "majority_baseline"),
        )
        accuracy = classifier_candidates[best_classifier]
        classifier_evaluation_method = "time_ordered_holdout_rule_labels"
    else:
        classifier_candidates = {
            "decision_tree": float(
                DecisionTreeClassifier(max_depth=4, random_state=42)
                .fit(X, waste_labels)
                .score(X, waste_labels)
            ),
            "random_forest_classifier": float(
                RandomForestClassifier(
                    n_estimators=180,
                    random_state=42,
                    min_samples_leaf=2,
                    max_depth=10,
                )
                .fit(X, waste_labels)
                .score(X, waste_labels)
            ),
        }
        best_classifier = max(classifier_candidates, key=classifier_candidates.get)
        accuracy = classifier_candidates[best_classifier]
        classifier_evaluation_method = "in_sample_rule_labels_small_dataset"

    return {
        "status": "trained",
        "rows": len(df),
        "regression": evaluation["best_model"],
        "regression_mae": evaluation["best_mae"],
        "regression_mape": evaluation["best_mape"],
        "evaluation_method": evaluation["evaluation_method"],
        "train_rows": evaluation["train_rows"],
        "test_rows": evaluation["test_rows"],
        "candidate_models": evaluation["candidates"],
        "classifier": best_classifier,
        "classifier_accuracy": round(accuracy, 3),
        "classifier_candidates": {
            name: round(score, 3) for name, score in classifier_candidates.items()
        },
        "classifier_evaluation_method": classifier_evaluation_method,
        "classifier_target": "rule_label_low_sales_waste_risk",
        "features": feature_columns,
    }


def _ml_quantity_prediction(
    restaurant_id: int,
    dish: Dish,
    target_date: date,
    weather: dict,
    calendar: dict,
    db: Session,
    model_context: dict | None = None,
):
    context = model_context or _quantity_model_context(restaurant_id, db)
    if context is None:
        return None

    df = context["frame"]
    model_name = context["model_name"]
    model = context["model"]
    history_features = _future_history_features(df, dish)
    row_data = {
        "dish_id": dish.id,
        "category_id": dish.category_id or 0,
        "day_of_week": target_date.weekday(),
        "is_weekend": int(target_date.weekday() >= 5),
        "month": target_date.month,
        "season": _season(target_date.month),
        "temperature": weather["temperature"],
        "humidity": weather["humidity"],
        "rain_probability": weather["rain_probability"],
        "has_event": int(bool(calendar["events"])),
        **history_features,
    }
    row = pd.DataFrame([row_data])
    for column in MODEL_FEATURE_COLUMNS:
        row[column] = pd.to_numeric(row[column], errors="coerce").fillna(0)

    if model is None:
        quantity = history_features["dish_recent_avg"]
    else:
        quantity = float(model.predict(row[MODEL_FEATURE_COLUMNS])[0])

    return {
        "quantity": max(0, quantity),
        "model": model_name,
    }


def _waste_risk(quantity: int, prep_quantity: int, weather: dict) -> str:
    if quantity <= 0 and prep_quantity <= 0:
        return "unknown"
    overage = prep_quantity - quantity
    rain = float(weather.get("rain_probability", 0) or 0)
    if overage >= max(5, quantity * 0.3) or rain >= 70:
        return "high"
    if overage >= max(3, quantity * 0.18) or rain >= 45:
        return "medium"
    return "low"


def hourly_forecast(expected_customers: int, target_date: date) -> list[dict]:
    weekend = target_date.weekday() >= 5
    lunch_share = 0.42 if weekend else 0.38
    dinner_share = 0.45 if weekend else 0.42
    other_share = max(0, 1 - lunch_share - dinner_share)
    return [
        {"label": "Morning", "hours": "08:00-11:00", "customers": _safe_int(expected_customers * other_share * 0.45)},
        {"label": "Lunch rush", "hours": "12:00-15:00", "customers": _safe_int(expected_customers * lunch_share)},
        {"label": "Evening", "hours": "16:00-18:00", "customers": _safe_int(expected_customers * other_share * 0.55)},
        {"label": "Dinner rush", "hours": "19:00-22:00", "customers": _safe_int(expected_customers * dinner_share)},
    ]


def inventory_estimate(dish_forecasts: list[dict], db: Session) -> list[dict]:
    totals = defaultdict(lambda: {"quantity": 0.0, "unit": "unit", "dishes": []})
    for forecast in dish_forecasts:
        recipes = db.query(InventoryRecipe).filter(InventoryRecipe.dish_id == forecast["dish_id"]).all()
        for recipe in recipes:
            item = totals[recipe.ingredient_name]
            item["quantity"] += (recipe.quantity_per_unit or 0) * forecast["preparation_quantity"]
            item["unit"] = recipe.unit or "unit"
            item["dishes"].append(forecast["name"])
    return [
        {
            "ingredient": ingredient,
            "quantity": round(values["quantity"], 2),
            "unit": values["unit"],
            "used_for": sorted(set(values["dishes"])),
        }
        for ingredient, values in sorted(totals.items())
    ]


def smart_recommendations(dish_forecasts: list[dict], weather: dict, calendar: dict) -> list[dict]:
    recommendations = []
    rain = float(weather.get("rain_probability", 0) or 0)
    temperature = float(weather.get("temperature", 0) or 0)
    events = calendar.get("events", [])

    if rain >= 50:
        recommendations.append(
            {
                "type": "weather",
                "priority": "high",
                "message": f"Rain chance is {rain:.0f}%. Reduce dine-in prep and watch high-waste items.",
            }
        )
    if temperature >= 32:
        recommendations.append(
            {
                "type": "weather",
                "priority": "medium",
                "message": "Hot weather expected. Increase cold beverages and lighter items.",
            }
        )
    if calendar.get("is_weekend"):
        recommendations.append(
            {
                "type": "calendar",
                "priority": "medium",
                "message": "Weekend detected. Expect stronger lunch and dinner rushes.",
            }
        )
    if events:
        names = ", ".join(event["name"] for event in events)
        recommendations.append(
            {
                "type": "festival",
                "priority": "high",
                "message": f"Calendar event coming: {names}. Prepare festival-sensitive inventory.",
            }
        )

    for forecast in dish_forecasts:
        if forecast["expected_quantity"] <= 0:
            continue
        if forecast["waste_risk"] == "high":
            recommendations.append(
                {
                    "type": "waste",
                    "priority": "high",
                    "dish_name": forecast["name"],
                    "message": f"{forecast['name']} has high waste risk. Prep around {forecast['preparation_quantity']} units and avoid extra batch cooking.",
                }
            )

    return recommendations


def smart_dashboard(restaurant_id: int, db: Session, target_date: date | None = None) -> dict:
    target_date = target_date or (date.today() + timedelta(days=1))
    weather_city = _weather_city_for_restaurant(restaurant_id, db)
    weather = get_weather_for_date(restaurant_id, target_date, db)
    calendar = get_calendar_context(restaurant_id, target_date, db)
    calendar_events = (
        db.query(CalendarEvent)
        .filter(
            CalendarEvent.event_date == target_date,
            (CalendarEvent.restaurant_id == restaurant_id) | (CalendarEvent.restaurant_id.is_(None)),
        )
        .all()
    )
    demand = predict_demand(restaurant_id, db).get("predictions", {})
    dishes = db.query(Dish).filter(Dish.restaurant_id == restaurant_id).all()
    quantity_model_context = _quantity_model_context(restaurant_id, db)

    dish_forecasts = []
    for dish in dishes:
        base = demand.get(dish.id) or demand.get(str(dish.id)) or {}
        ml_prediction = _ml_quantity_prediction(
            restaurant_id,
            dish,
            target_date,
            weather,
            calendar,
            db,
            quantity_model_context,
        )
        base_next_day = base.get("next_day", 0) or 0
        if ml_prediction is not None:
            ml_quantity = ml_prediction["quantity"]
            if base_next_day > 0 and base.get("confidence") in ("high", "medium"):
                base_quantity = max(base_next_day, ml_quantity)
                model_name = f"full_signal_{ml_prediction['model']}_{base.get('method', 'timeseries')}"
            else:
                base_quantity = ml_quantity
                model_name = ml_prediction["model"]
        else:
            base_quantity = base_next_day
            model_name = base.get("method", "baseline")
        adjusted = base_quantity * _dish_weather_multiplier(dish, weather) * _calendar_multiplier(dish, target_date, calendar_events)
        quantity = _safe_int(adjusted)
        prep_quantity = _safe_int(quantity * 1.08)
        unit_price = dish.selling_price or 0
        unit_cost = _unit_ingredient_cost(dish)
        cost_missing = unit_cost is None
        numeric_unit_cost = unit_cost if unit_cost is not None else 0
        margin_fraction = _prediction_margin(dish)
        margin = 0 if margin_fraction is None else margin_fraction * 100
        risk = _waste_risk(quantity, prep_quantity, weather)
        dish_forecasts.append(
            {
                "dish_id": dish.id,
                "name": dish.name,
                "category_id": dish.category_id,
                "expected_quantity": quantity,
                "next_week_quantity": base.get("next_week", quantity),
                "preparation_quantity": prep_quantity,
                "expected_sales": round(quantity * unit_price, 2),
                "margin": round(margin, 1),
                "unit_cost": numeric_unit_cost,
                "cost_status": "missing_cost" if cost_missing else "ok",
                "waste_risk": risk,
                "confidence": base.get("confidence", "ml_adjusted"),
                "model": model_name,
            }
        )

        record = (
            db.query(PredictionRecord)
            .filter(
                PredictionRecord.restaurant_id == restaurant_id,
                PredictionRecord.dish_id == dish.id,
                PredictionRecord.prediction_date == target_date,
                PredictionRecord.model_name == "smart_dashboard",
            )
            .first()
        )
        if not record:
            record = PredictionRecord(
                restaurant_id=restaurant_id,
                dish_id=dish.id,
                prediction_date=target_date,
                model_name="smart_dashboard",
            )
            db.add(record)
        record.expected_customers = 0
        record.expected_sales = round(quantity * unit_price, 2)
        record.next_day_quantity = quantity
        record.next_week_quantity = base.get("next_week", quantity)
        record.preparation_quantity = prep_quantity
        record.waste_risk = risk
        record.busy_hours = "[]"
        record.confidence = base.get("confidence", "ml_adjusted")

    expected_sales = sum(item["expected_sales"] for item in dish_forecasts)
    expected_customers = _safe_int(sum(item["expected_quantity"] for item in dish_forecasts) * 0.65)
    hours = hourly_forecast(expected_customers, target_date)
    inventory = inventory_estimate(dish_forecasts, db)
    recommendations = smart_recommendations(dish_forecasts, weather, calendar)
    model_report = train_model_report(restaurant_id, db)

    for record in db.query(PredictionRecord).filter(
        PredictionRecord.restaurant_id == restaurant_id,
        PredictionRecord.prediction_date == target_date,
        PredictionRecord.model_name == "smart_dashboard",
    ):
        record.expected_customers = expected_customers
        record.busy_hours = json.dumps(hours)
    db.commit()

    return {
        "prediction_date": target_date,
        "expected_customers": expected_customers,
        "expected_sales": round(expected_sales, 2),
        "weather_city": weather_city,
        "weather": weather,
        "calendar": calendar,
        "dish_forecasts": sorted(dish_forecasts, key=lambda item: item["expected_quantity"], reverse=True),
        "hourly_forecast": hours,
        "inventory_estimate": inventory,
        "recommendations": recommendations,
        "model_report": model_report,
    }


def _chat_context(restaurant_id: int, db: Session, dish_id: int | None = None) -> dict:
    dashboard = smart_dashboard(restaurant_id, db)
    forecasts = dashboard.get("dish_forecasts", [])
    selected = None
    if dish_id is not None:
        selected = next((item for item in forecasts if item["dish_id"] == dish_id), None)
    return {
        "weather": dashboard.get("weather", {}),
        "calendar": dashboard.get("calendar", {}),
        "expected_customers": dashboard.get("expected_customers", 0),
        "expected_sales": dashboard.get("expected_sales", 0),
        "selected_dish": selected,
        "top_forecasts": forecasts[:8],
        "recommendations": dashboard.get("recommendations", [])[:8],
        "model_report": dashboard.get("model_report", {}),
    }


def _local_chat_reply(message: str, context: dict) -> str:
    selected = context.get("selected_dish")
    weather = context.get("weather", {})
    calendar = context.get("calendar", {})
    recommendations = context.get("recommendations", [])
    top = context.get("top_forecasts", [])
    lower = message.lower()

    if selected:
        margin = selected.get("margin")
        margin_text = (
            "unknown because ingredient cost is missing"
            if selected.get("cost_status") == "missing_cost"
            else f"{margin}%"
        )
        return (
            f"For {selected['name']}, prepare about {selected['preparation_quantity']} units. "
            f"Expected demand is {selected['expected_quantity']} units, margin is {margin_text}, "
            f"and waste risk is {selected['waste_risk']}. Weather source is {weather.get('source', 'baseline')} "
            f"with {weather.get('temperature', 0)} C and {weather.get('rain_probability', 0)}% rain chance."
        )

    if "weather" in lower or "rain" in lower:
        return (
            f"Weather is {weather.get('condition', 'baseline')} from {weather.get('source', 'baseline')}: "
            f"{weather.get('temperature', 0)} C, {weather.get('humidity', 0)}% humidity, "
            f"{weather.get('rain_probability', 0)}% rain chance. Keep the forecast city in the restaurant profile "
            f"and set OPENWEATHER_API_KEY or WEATHERAPI_KEY for live data."
        )

    if "calendar" in lower or "festival" in lower or "holiday" in lower:
        events = calendar.get("events", [])
        if events:
            names = ", ".join(event["name"] for event in events)
            return f"Calendar has these events: {names}. Increase event-sensitive items and monitor waste."
        return f"Calendar shows {calendar.get('day_of_week')} with no stored festival event. Refresh Nager.Date holidays or add manual events."

    if recommendations:
        return recommendations[0].get("message", "")

    if top:
        if all((item.get("expected_quantity") or 0) <= 0 for item in top):
            return "I need more sales history before recommending prep quantities. Add a few days of sales so the demand model can learn this menu."
        best = top[0]
        return f"Top forecast item is {best['name']} with {best['expected_quantity']} expected units. Prepare around {best['preparation_quantity']} units."

    return "I need more sales/menu data before making a strong recommendation."


async def chat_recommendation(restaurant_id: int, message: str, dish_id: int | None, db: Session) -> dict:
    await ensure_live_intelligence_context(restaurant_id, db)
    context = _chat_context(restaurant_id, db, dish_id)
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        return {
            "reply": _local_chat_reply(message, context),
            "provider": "local_ml_assistant",
            "context": context,
        }

    prompt = (
        "You are an AI restaurant operations assistant. Use only the provided JSON context. "
        "Do not invent sales numbers. Give concise, practical recommendations about food prep, "
        "weather, calendar/festival impact, margin, waste, and inventory. "
        f"User question: {message}\nContext JSON: {json.dumps(context, default=str)}"
    )
    model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash").strip()
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{model_name}:generateContent"
    )
    payload = {"contents": [{"parts": [{"text": prompt}]}]}
    try:
        async with httpx.AsyncClient(timeout=20) as client:
            response = await client.post(f"{url}?key={api_key}", json=payload)
            response.raise_for_status()
            data = response.json()
    except (httpx.HTTPError, KeyError, IndexError, TypeError, ValueError):
        return {
            "reply": _local_chat_reply(message, context),
            "provider": "local_ml_assistant",
            "context": context,
        }
    reply = (
        data.get("candidates", [{}])[0]
        .get("content", {})
        .get("parts", [{}])[0]
        .get("text", "")
        .strip()
    )
    return {
        "reply": reply or _local_chat_reply(message, context),
        "provider": "gemini",
        "context": context,
    }
