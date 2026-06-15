from sklearn.ensemble import RandomForestRegressor
from sklearn.linear_model import LinearRegression
import pandas as pd
import numpy as np
from sqlalchemy.orm import Session
from models.sales import DailySales, SalesItem
from models.menu import Dish
from models.waste import WasteEntry

def _as_units(value):
    if value is None or not np.isfinite(value):
        return 0
    return max(0, int(round(value)))

def _servings_per_batch(dish):
    servings = getattr(dish, "servings_per_batch", None) or 1
    return max(1, servings)

def _unit_ingredient_cost(dish):
    batch_cost = float(dish.ingredient_cost or 0)
    if batch_cost <= 0:
        return None
    return batch_cost / _servings_per_batch(dish)

def _prediction_margin(dish):
    unit_price = float(dish.selling_price or 0)
    unit_cost = _unit_ingredient_cost(dish)
    if unit_price <= 0 or unit_cost is None:
        return None
    return (unit_price - unit_cost) / unit_price

def _prediction_payload(dish, next_day, next_week, confidence, method, history_days=0):
    return {
        "name": dish.name,
        "next_day": _as_units(next_day),
        "next_week": _as_units(next_week),
        "confidence": confidence,
        "method": method,
        "history_days": history_days,
    }

def _sales_dataframe(sales):
    rows = []
    sale_dates = []
    for sale in sales:
        sale_dates.append(sale.sale_date)
        for item in sale.sales_items:
            rows.append({
                "date": sale.sale_date,
                "dish_id": item.dish_id,
                "quantity": item.quantity_sold or 0,
            })

    if not sale_dates:
        return pd.DataFrame(columns=["date", "dish_id", "quantity"]), []

    df = pd.DataFrame(rows, columns=["date", "dish_id", "quantity"])
    if not df.empty:
        df["date"] = pd.to_datetime(df["date"])
        df = df.groupby(["date", "dish_id"], as_index=False)["quantity"].sum()

    unique_dates = sorted(pd.to_datetime(pd.Series(sale_dates)).drop_duplicates())
    return df, unique_dates

def _dish_daily_series(sales_df, sale_dates, dish_id):
    if not sale_dates:
        return pd.DataFrame(columns=["date", "quantity"])

    date_index = pd.DatetimeIndex(sale_dates)
    if sales_df.empty:
        quantities = pd.Series(0, index=date_index)
    else:
        dish_df = sales_df[sales_df["dish_id"] == dish_id].set_index("date")
        quantities = dish_df["quantity"].reindex(date_index, fill_value=0)

    return pd.DataFrame({"date": date_index, "quantity": quantities.values})

def _recent_average(series, window=7):
    if series.empty:
        return 0
    recent = series["quantity"].tail(window)
    return float(recent.mean()) if not recent.empty else 0

def _weighted_recent_average_from_values(values):
    history = [float(value) for value in values if pd.notna(value)]
    if not history:
        return 0
    recent_7 = float(np.mean(history[-7:]))
    recent_14 = float(np.mean(history[-14:]))
    full_avg = float(np.mean(history))
    trend = 0.0
    if len(history) >= 14:
        trend = recent_7 - float(np.mean(history[-14:-7]))
    elif len(history) >= 4:
        split = max(1, len(history) // 2)
        trend = recent_7 - float(np.mean(history[:split]))
    trend_weight = 0.30 if trend > 0 else 0.12
    return max(
        0.0,
        (recent_7 * 0.50)
        + (recent_14 * 0.25)
        + (full_avg * 0.10)
        + (trend * trend_weight),
    )

def _weighted_recent_average(series):
    if series.empty:
        return 0
    return _weighted_recent_average_from_values(series["quantity"].tolist())

def _category_baselines(dishes, sales_df, sale_dates):
    restaurant_values = []
    category_values = {}
    for dish in dishes:
        series = _dish_daily_series(sales_df, sale_dates, dish.id)
        if series.empty or series["quantity"].sum() <= 0:
            continue

        recent_avg = _recent_average(series)
        restaurant_values.append(recent_avg)
        category_values.setdefault(dish.category_id, []).append(recent_avg)

    restaurant_baseline = float(np.mean(restaurant_values)) if restaurant_values else 0
    return {
        category_id: float(np.mean(values))
        for category_id, values in category_values.items()
        if values
    }, restaurant_baseline

def _forecast_with_history(series):
    series = series.copy().sort_values("date").reset_index(drop=True)
    series["days"] = (series["date"] - series["date"].min()).dt.days
    history_days = len(series)
    active_days = int((series["quantity"] > 0).sum())

    if history_days < 7 or active_days < 7:
        recent_avg = _weighted_recent_average(series)
        return recent_avg, recent_avg, "limited_history", "sparse_recent_average", history_days

    if history_days < 14 or active_days < 14:
        recent_avg = _weighted_recent_average(series)
        return recent_avg, recent_avg, "medium", "weighted_recent_average", history_days

    train = series.copy()
    train["day_of_week"] = train["date"].dt.dayofweek
    train["lag_1"] = train["quantity"].shift(1)
    train["lag_7"] = train["quantity"].shift(7)
    train["rolling_7"] = train["quantity"].shift(1).rolling(7).mean()
    train["rolling_14"] = train["quantity"].shift(1).rolling(14).mean()
    train = train.dropna()

    if len(train) < 8:
        recent_avg = _weighted_recent_average(series)
        return recent_avg, recent_avg, "medium", "weighted_recent_average", history_days

    feature_columns = ["days", "day_of_week", "lag_1", "lag_7", "rolling_7", "rolling_14"]
    X = train[feature_columns]
    y = train["quantity"]

    forest = RandomForestRegressor(
        n_estimators=120,
        random_state=42,
        min_samples_leaf=2,
    )
    forest.fit(X, y)

    linear = LinearRegression()
    linear.fit(train[["days"]], y)

    future_values = []
    history = series["quantity"].astype(float).tolist()
    last_date = series["date"].max()
    max_day = int(series["days"].max())

    for offset in range(1, 8):
        future_date = last_date + pd.Timedelta(days=offset)
        lag_1 = history[-1] if history else 0
        lag_7 = history[-7] if len(history) >= 7 else _recent_average(series)
        rolling_7 = float(np.mean(history[-7:])) if history else 0
        rolling_14 = float(np.mean(history[-14:])) if history else rolling_7
        future_row = pd.DataFrame([{
            "days": max_day + offset,
            "day_of_week": future_date.dayofweek,
            "lag_1": lag_1,
            "lag_7": lag_7,
            "rolling_7": rolling_7,
            "rolling_14": rolling_14,
        }])

        forest_prediction = forest.predict(future_row[feature_columns])[0]
        trend_row = pd.DataFrame([{"days": max_day + offset}])
        trend_prediction = linear.predict(trend_row)[0]
        weighted_recent = _weighted_recent_average_from_values(history)
        blended_prediction = (
            forest_prediction * 0.55
            + trend_prediction * 0.20
            + weighted_recent * 0.25
        )
        blended_prediction = max(blended_prediction, weighted_recent)
        prediction = max(0, blended_prediction)
        future_values.append(prediction)
        history.append(prediction)

    confidence = "high" if history_days >= 28 and active_days >= 28 else "medium"
    return future_values[0], float(np.mean(future_values)), confidence, "random_forest_trend", history_days

def predict_demand(restaurant_id: int, db: Session):
    dishes = db.query(Dish).filter(Dish.restaurant_id == restaurant_id).all()

    # Get historical sales data
    sales = db.query(DailySales).filter(DailySales.restaurant_id == restaurant_id).order_by(DailySales.sale_date).all()
    sales_df, sale_dates = _sales_dataframe(sales)
    category_baselines, restaurant_baseline = _category_baselines(dishes, sales_df, sale_dates)

    predictions = {}
    for dish in dishes:
        series = _dish_daily_series(sales_df, sale_dates, dish.id)
        if series.empty:
            predictions[dish.id] = _prediction_payload(
                dish,
                0,
                0,
                "no_history",
                "no_sales_data",
            )
            continue

        if series["quantity"].sum() <= 0:
            baseline = category_baselines.get(dish.category_id, restaurant_baseline)
            confidence = "category_baseline" if dish.category_id in category_baselines else "restaurant_baseline"
            if baseline <= 0:
                confidence = "no_history"
            predictions[dish.id] = _prediction_payload(
                dish,
                baseline,
                baseline,
                confidence,
                "cold_start_baseline",
                len(series),
            )
            continue

        next_day, next_week, confidence, method, history_days = _forecast_with_history(series)
        predictions[dish.id] = _prediction_payload(
            dish,
            next_day,
            next_week,
            confidence,
            method,
            history_days,
        )

    return {"predictions": predictions}

def classify_dishes(restaurant_id: int, db: Session):
    dishes = db.query(Dish).filter(Dish.restaurant_id == restaurant_id).all()
    classifications = {}

    for dish in dishes:
        # Get total sales
        total_sold = db.query(SalesItem).filter(SalesItem.dish_id == dish.id).with_entities(SalesItem.quantity_sold).all()
        total_quantity = sum((q[0] or 0) for q in total_sold)

        margin = _prediction_margin(dish)

        # Simple classification based only on sold quantity. Ingredient cost is
        # kept as menu metadata and should not change demand priority.
        if total_quantity == 0:
            demand = "new"
        elif total_quantity > 100:
            demand = "high"
        elif total_quantity > 50:
            demand = "medium"
        else:
            demand = "low"

        classifications[dish.id] = {
            "name": dish.name,
            "total_sold": total_quantity,
            "margin": margin,
            "demand_level": demand
        }

    return {"classifications": classifications}

def analyze_profit(restaurant_id: int, db: Session):
    dishes = db.query(Dish).filter(Dish.restaurant_id == restaurant_id).all()
    analysis = []

    for dish in dishes:
        sold_rows = db.query(SalesItem).filter(SalesItem.dish_id == dish.id).with_entities(
            SalesItem.quantity_sold,
            SalesItem.revenue,
        ).all()
        total_quantity = sum(row[0] or 0 for row in sold_rows)
        unit_cost = _unit_ingredient_cost(dish)
        cost_missing = unit_cost is None
        numeric_unit_cost = unit_cost if unit_cost is not None else 0
        total_cost = total_quantity * numeric_unit_cost
        total_revenue = sum(row[1] or 0 for row in sold_rows)
        unit_price = dish.selling_price or 0
        unit_profit = 0 if cost_missing else unit_price - numeric_unit_cost
        total_profit = 0 if cost_missing else total_revenue - total_cost
        margin = _prediction_margin(dish) or 0

        analysis.append({
            "dish_id": dish.id,
            "name": dish.name,
            "total_sold": total_quantity,
            "batch_cost": dish.ingredient_cost or 0,
            "servings_per_batch": _servings_per_batch(dish),
            "unit_cost": numeric_unit_cost,
            "unit_price": unit_price,
            "unit_profit": unit_profit,
            "total_cost": total_cost,
            "total_revenue": total_revenue,
            "profit": total_profit,
            "total_profit": total_profit,
            "margin": margin,
            "menu_margin": margin,
            "cost_status": "missing_cost" if cost_missing else "ok",
        })

    # Sort by profit descending
    analysis.sort(
        key=lambda x: (
            x["total_profit"] if x["total_profit"] is not None else float("-inf"),
            x["unit_profit"] if x["unit_profit"] is not None else float("-inf"),
        ),
        reverse=True,
    )
    return {"analysis": analysis}

def generate_suggestions(restaurant_id: int, db: Session):
    predictions = predict_demand(restaurant_id, db)

    suggestions = []

    # Prep suggestions based on predictions
    for dish_id, pred in predictions['predictions'].items():
        dish = db.query(Dish).filter(Dish.id == dish_id).first()
        if dish:
            next_week_avg = pred['next_week']
            if pred.get('confidence') == 'no_history' or next_week_avg <= 0:
                continue
            if pred.get('method') == 'cold_start_baseline':
                message = f"Start with approximately {next_week_avg} units of {dish.name} based on similar menu demand"
            else:
                message = f"Prepare approximately {next_week_avg} units of {dish.name} for next week"
            suggestions.append({
                "type": "prep",
                "dish_name": dish.name,
                "message": message,
                "quantity": next_week_avg
            })

    # Waste reduction suggestions
    waste_data = db.query(WasteEntry).filter(WasteEntry.restaurant_id == restaurant_id).all()
    waste_by_reason = {}
    for waste in waste_data:
        reason = waste.reason
        if reason not in waste_by_reason:
            waste_by_reason[reason] = 0
        waste_by_reason[reason] += waste.quantity_wasted

    for reason, quantity in waste_by_reason.items():
        if quantity > 10:  # Arbitrary threshold
            suggestions.append({
                "type": "waste",
                "message": f"High waste due to '{reason}'. Review portion sizes or ordering to reduce waste.",
                "reason": reason,
                "quantity": quantity
            })

    return {"suggestions": suggestions}
