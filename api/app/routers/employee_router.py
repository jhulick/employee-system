from fastapi import APIRouter, HTTPException
from app.schemas.employee_schemas import EmployeeRequest, EmployeeCreate
from app.config.db_config import get_database, get_employee_collection
from app.crud.employees_crud import get_employees, create_employee

router = APIRouter()

@router.get("/employees")
def add_employees():
    db = get_database()
    collection = get_employee_collection(db)
    return collection.all()

@router.get("/health")
def health_check():
    return {"status": "ok"}