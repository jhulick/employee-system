import pytest
from datetime import time, datetime
from app.crud.employees_crud import create_employee, get_recommended_employee
from app.schemas.employee_schemas import EmployeeCreate, EmployeeRequest


@pytest.fixture
def new_employee():
    """
    Fixture to create a new EmployeeCreate object for testing.
    """
    return EmployeeCreate(
        name="Test employee",
        style="Test Style",
        address="Test Address",
        vegetarian=True,
        open_hour="10:00",
        close_hour="22:00"
    )


@pytest.fixture
def employee_request():
    """
    Fixture to create a EmployeeRequest object for testing recommendations.
    """
    return EmployeeRequest(
        style="Test Style",
        vegetarian=True,
        open_now=True
    )


def test_create_employee(test_db, new_employee):
    """
    Test case for creating a new employee in the database.
    """
    collection = test_db.get_collection("employees")
    created_employee = create_employee(collection, new_employee)
    assert created_employee["name"] == new_employee.name
    assert created_employee["style"] == new_employee.style


def test_create_employee_duplicate(test_db, new_employee):
    """
    Test case for creating a duplicate employee in the database.
    """
    collection = test_db.get_collection("employees")
    create_employee(collection, new_employee)
    with pytest.raises(Exception):
        create_employee(collection, new_employee)
