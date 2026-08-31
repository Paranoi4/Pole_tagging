from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional

from config.database import get_db
import models.models as models
import models.schemas as schemas
from utils.auth import get_current_user, require_role

router = APIRouter(prefix="/cities", tags=["Cities"])


@router.post("", response_model=schemas.CityOut, dependencies=[Depends(require_role("Admin"))])
def create_city(
    city: schemas.CityCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    du = db.query(models.DistributionUtility).filter(
        models.DistributionUtility.du_id == city.du_id,
        models.DistributionUtility.org_code == current_user.org_code
    ).first()
    if not du:
        raise HTTPException(status_code=404, detail="DU not found in your organization")

    db_city = models.City(
        city_name=city.city_name,
        du_id=city.du_id,
        org_code=current_user.org_code,
        created_by=current_user.user_id,
    )
    db.add(db_city)
    db.commit()
    db.refresh(db_city)
    return db_city


@router.get("", response_model=List[schemas.CityOut])
def list_cities(
    du_id: Optional[int] = Query(None, description="Filter by DU"),
    search: Optional[str] = Query(None, min_length=1, max_length=255, description="Case-insensitive search on city name, e.g. for autocomplete"),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    query = db.query(models.City).filter(models.City.org_code == current_user.org_code)
    if du_id:
        query = query.filter(models.City.du_id == du_id)
    if search:
        query = query.filter(models.City.city_name.ilike(f"%{search}%"))
    return query.order_by(models.City.city_name).limit(20).all()

# ===== GET CITY BY ID =====
@router.get("/{city_id}", response_model=schemas.CityOut)
def get_city(
    city_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    city = db.query(models.City).filter(
        models.City.city_id == city_id,
        models.City.org_code == current_user.org_code
    ).first()
    if not city:
        raise HTTPException(status_code=404, detail="City not found")
    return city


# ===== UPDATE CITY =====
@router.put("/{city_id}", response_model=schemas.CityOut, dependencies=[Depends(require_role("Admin"))])
def update_city(
    city_id: int,
    patch: schemas.CityUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    city = db.query(models.City).filter(
        models.City.city_id == city_id,
        models.City.org_code == current_user.org_code
    ).first()
    if not city:
        raise HTTPException(status_code=404, detail="City not found")

    data = patch.model_dump(exclude_unset=True)

    # If du_id is being changed, verify the new DU exists in this org too.
    if "du_id" in data and data["du_id"] is not None:
        du = db.query(models.DistributionUtility).filter(
            models.DistributionUtility.du_id == data["du_id"],
            models.DistributionUtility.org_code == current_user.org_code
        ).first()
        if not du:
            raise HTTPException(status_code=404, detail="DU not found in your organization")

    for field, value in data.items():
        if value is not None:
            setattr(city, field, value)

    db.commit()
    db.refresh(city)
    return city


# ===== DELETE CITY =====
@router.delete("/{city_id}", dependencies=[Depends(require_role("Admin"))])
def delete_city(
    city_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    city = db.query(models.City).filter(
        models.City.city_id == city_id,
        models.City.org_code == current_user.org_code
    ).first()
    if not city:
        raise HTTPException(status_code=404, detail="City not found")

    city_name = city.city_name
    db.delete(city)
    db.commit()
    return {"message": f"City '{city_name}' deleted successfully"}