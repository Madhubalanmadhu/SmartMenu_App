from fastapi import APIRouter, Depends, HTTPException, Header
from fastapi.encoders import jsonable_encoder
from sqlalchemy.orm import Session
from database import get_db
from models.intelligence import CalendarEvent, InventoryRecipe, PredictionRecord, WeatherSnapshot
from models.menu import Category, Dish
from models.sales import DailySales
from models.user import User, Restaurant
from models.waste import WasteEntry
from schemas.user import UserCreate, RestaurantCreate, User as UserSchema, Restaurant as RestaurantSchema
import firebase_admin
from firebase_admin import auth, credentials
import base64
import json
import os

router = APIRouter()

# Initialize Firebase Admin SDK if credentials are available
if os.getenv("FIREBASE_PROJECT_ID") and os.getenv("FIREBASE_PRIVATE_KEY"):
    cred = credentials.Certificate({
        "type": "service_account",
        "project_id": os.getenv("FIREBASE_PROJECT_ID"),
        "private_key": os.getenv("FIREBASE_PRIVATE_KEY").replace("\\n", "\n"),
        "client_email": os.getenv("FIREBASE_CLIENT_EMAIL"),
        "token_uri": "https://oauth2.googleapis.com/token",
    })
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
else:
    # For development, skip Firebase if not configured
    pass

def get_current_user(authorization: str = Header(None)):
    """Dependency to get current user from Authorization header."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authentication token")
    token = authorization.split(" ")[1]
    decoded = verify_firebase_token(token)
    return decoded

def _dev_auth_bypass_enabled() -> bool:
    return os.getenv("ALLOW_DEV_AUTH_BYPASS", "").lower() in {"1", "true", "yes"}


def _decode_unverified_firebase_uid(token: str):
    try:
        payload = token.split(".")[1]
        padding = "=" * (-len(payload) % 4)
        decoded = base64.urlsafe_b64decode(payload + padding)
        claims = json.loads(decoded)
        return claims.get("user_id") or claims.get("sub") or claims.get("uid")
    except Exception:
        return None


def verify_firebase_token(token: str):
    if not firebase_admin._apps:
        uid = _decode_unverified_firebase_uid(token) if _dev_auth_bypass_enabled() else None
        # For development, return dummy uid if Firebase Admin is not configured.
        return {"uid": uid or "dev-user-123"}
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        if _dev_auth_bypass_enabled():
            uid = _decode_unverified_firebase_uid(token)
            if uid:
                return {"uid": uid}
        raise HTTPException(status_code=401, detail="Invalid token")

def get_current_db_user(current_user: dict, db: Session) -> User:
    user = db.query(User).filter(User.firebase_uid == current_user["uid"]).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user

def require_restaurant_owner(
    restaurant_id: int,
    current_user: dict,
    db: Session,
) -> Restaurant:
    user = get_current_db_user(current_user, db)
    restaurant = (
        db.query(Restaurant)
        .filter(Restaurant.id == restaurant_id, Restaurant.user_id == user.id)
        .first()
    )
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    return restaurant

def _model_dict(row):
    return {column.name: getattr(row, column.name) for column in row.__table__.columns}

@router.post("/register", response_model=UserSchema)
def register(
    user: UserCreate,
    current_user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if user.firebase_uid != current_user["uid"]:
        raise HTTPException(status_code=403, detail="Cannot register another user")

    existing_user = db.query(User).filter(
        (User.firebase_uid == user.firebase_uid) | (User.email == user.email)
    ).first()
    if existing_user:
        if existing_user.firebase_uid != current_user["uid"]:
            raise HTTPException(status_code=403, detail="Email belongs to another user")
        return existing_user

    db_user = User(**user.dict())
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@router.post("/restaurant", response_model=RestaurantSchema)
def create_restaurant(restaurant: RestaurantCreate, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = get_current_db_user(current_user, db)
    existing_restaurant = db.query(Restaurant).filter(Restaurant.user_id == user.id).first()
    if existing_restaurant:
        for key, value in restaurant.dict().items():
            setattr(existing_restaurant, key, value)
        db.commit()
        db.refresh(existing_restaurant)
        return existing_restaurant

    db_restaurant = Restaurant(user_id=user.id, **restaurant.dict())
    db.add(db_restaurant)
    db.commit()
    db.refresh(db_restaurant)
    return db_restaurant

@router.get("/profile", response_model=UserSchema)
def get_profile(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    return get_current_db_user(current_user, db)

@router.get("/restaurant", response_model=RestaurantSchema)
def get_restaurant(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = get_current_db_user(current_user, db)
    restaurant = db.query(Restaurant).filter(Restaurant.user_id == user.id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    return restaurant

@router.get("/restaurant/export")
def export_restaurant_data(current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = get_current_db_user(current_user, db)
    restaurant = db.query(Restaurant).filter(Restaurant.user_id == user.id).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")

    dishes = db.query(Dish).filter(Dish.restaurant_id == restaurant.id).all()
    dish_ids = [dish.id for dish in dishes]

    sales = db.query(DailySales).filter(DailySales.restaurant_id == restaurant.id).all()

    return jsonable_encoder({
        "user": _model_dict(user),
        "restaurant": _model_dict(restaurant),
        "categories": [
            _model_dict(category)
            for category in db.query(Category).filter(Category.restaurant_id == restaurant.id).all()
        ],
        "dishes": [_model_dict(dish) for dish in dishes],
        "sales": [
            {
                **_model_dict(sale),
                "sales_items": [_model_dict(item) for item in sale.sales_items],
            }
            for sale in sales
        ],
        "waste_entries": [
            _model_dict(entry)
            for entry in db.query(WasteEntry).filter(WasteEntry.restaurant_id == restaurant.id).all()
        ],
        "weather_snapshots": [
            _model_dict(snapshot)
            for snapshot in db.query(WeatherSnapshot).filter(WeatherSnapshot.restaurant_id == restaurant.id).all()
        ],
        "calendar_events": [
            _model_dict(event)
            for event in db.query(CalendarEvent).filter(
            (CalendarEvent.restaurant_id == restaurant.id)
            | (CalendarEvent.restaurant_id.is_(None))
            ).all()
        ],
        "inventory_recipes": [
            _model_dict(recipe)
            for recipe in db.query(InventoryRecipe).filter(
            InventoryRecipe.dish_id.in_(dish_ids)
            ).all()
        ] if dish_ids else [],
        "prediction_records": [
            _model_dict(record)
            for record in db.query(PredictionRecord).filter(
            PredictionRecord.restaurant_id == restaurant.id
            ).all()
        ],
    })

@router.put("/restaurant", response_model=RestaurantSchema)
def update_restaurant(restaurant: RestaurantCreate, current_user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    user = get_current_db_user(current_user, db)
    db_restaurant = db.query(Restaurant).filter(Restaurant.user_id == user.id).first()
    if not db_restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    for key, value in restaurant.dict().items():
        setattr(db_restaurant, key, value)
    db.commit()
    db.refresh(db_restaurant)
    return db_restaurant
