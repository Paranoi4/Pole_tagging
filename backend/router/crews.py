from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List,  Optional

from config.database import get_db
import models.models as models
import models.schemas as schemas
from models.enums import RoleName
from utils.auth import get_current_user, require_role

router = APIRouter(prefix="/crews", tags=["Crews"])


@router.post("", response_model=schemas.CrewOut, dependencies=[Depends(require_role(RoleName.ADMIN))])
def create_crew(
    crew: schemas.CrewCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    if crew.city_id is not None:
        city = db.query(models.City).filter(
            models.City.city_id == crew.city_id,
            models.City.org_code == current_user.org_code
        ).first()
        if not city:
            raise HTTPException(status_code=404, detail="City not found in your organization")

    db_crew = models.Crew(
        crew_label=crew.crew_label,
        city_id=crew.city_id,
        org_code=current_user.org_code,
        created_by=current_user.user_id,
    )
    db.add(db_crew)
    db.commit()
    db.refresh(db_crew)
    return db_crew


@router.get("", response_model=List[schemas.CrewOut])
def list_crews(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    city_id: Optional[int] = Query(None, description="Filter by city"),
    du_id: Optional[int] = Query(
        None,
        description="Only crews working a city under this DU",
    ),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """List crews for the caller's organization.

    `du_id` narrows this to the crews that actually work that DU, reached
    through the city they are tied to. The dispatcher needs it: a batch belongs
    to one DU, and offering crews from a different DU invites handing a batch to
    people who will never see those poles. Crews with no city are excluded by
    the join, which is correct — an unplaced crew cannot be dispatched to.
    """
    query = db.query(models.Crew).filter(
        models.Crew.org_code == current_user.org_code
    )

    if du_id:
        # The DU is checked on the city, and the city's org is checked too, so a
        # DU id belonging to another organization matches nothing rather than
        # leaking its crews.
        query = query.join(models.City, models.Crew.city_id == models.City.city_id).filter(
            models.City.du_id == du_id,
            models.City.org_code == current_user.org_code,
        )

    if city_id:
        query = query.filter(models.Crew.city_id == city_id)

    crews = query.order_by(models.Crew.crew_label).offset(skip).limit(limit).all()
    return crews


# Also add a GET by ID endpoint:
@router.get("/{crew_id}", response_model=schemas.CrewOut)
def get_crew(
    crew_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Get a single crew by ID."""
    crew = db.query(models.Crew).filter(
        models.Crew.crew_id == crew_id,
        models.Crew.org_code == current_user.org_code
    ).first()
    if not crew:
        raise HTTPException(status_code=404, detail="Crew not found")
    return crew

# ===== UPDATE CREW =====
@router.put("/{crew_id}", response_model=schemas.CrewOut, dependencies=[Depends(require_role(RoleName.ADMIN))])
def update_crew(
    crew_id: int,
    patch: schemas.CrewUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Admin can only update crews within their own organization."""
    crew = db.query(models.Crew).filter(
        models.Crew.crew_id == crew_id,
        models.Crew.org_code == current_user.org_code
    ).first()
    if not crew:
        raise HTTPException(status_code=404, detail="Crew not found")

    data = patch.model_dump(exclude_unset=True)

    # Same as create_crew: if city_id is being changed, make sure the new
    # city actually exists and belongs to this org before saving it.
    if "city_id" in data and data["city_id"] is not None:
        city = db.query(models.City).filter(
            models.City.city_id == data["city_id"],
            models.City.org_code == current_user.org_code
        ).first()
        if not city:
            raise HTTPException(status_code=404, detail="City not found in your organization")

    # crew_label is NOT NULL, so an explicit null here reaches the database as a
    # constraint violation and surfaces as a 500. city_id is nullable and a null
    # there is meaningful — that is how a crew is unassigned from a city — so
    # the two cannot share the blanket "skip None" the other routers use.
    if "crew_label" in data and data["crew_label"] is None:
        raise HTTPException(status_code=400, detail="Crew label cannot be empty")

    for field, value in data.items():
        setattr(crew, field, value)

    db.commit()
    db.refresh(crew)
    return crew


# ===== DELETE CREW =====
@router.delete("/{crew_id}", dependencies=[Depends(require_role(RoleName.ADMIN))])
def delete_crew(
    crew_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user),
):
    """Admin can only delete crews within their own organization."""
    crew = db.query(models.Crew).filter(
        models.Crew.crew_id == crew_id,
        models.Crew.org_code == current_user.org_code
    ).first()
    if not crew:
        raise HTTPException(status_code=404, detail="Crew not found")

    crew_label = crew.crew_label
    db.delete(crew)
    db.commit()
    return {"message": f"Crew '{crew_label}' deleted successfully"}