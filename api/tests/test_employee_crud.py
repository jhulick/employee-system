import pytest
from datetime import time, datetime
from app.crud.employees_crud import create_employee, get_recommended_employee
from app.schemas.employee_schemas import EmployeeCreate, EmployeeRequest


@pytest.fixture
def new_employee():
    """
    Fixture to create a new employeeCreate object for testing.
    """
    return EmployeeCreate(
        name="Test Employee",
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


def test_get_recommended_employee(test_db, new_employee, employee_request):
    """
    Test case for getting a recommended employee from the database.
    """
    collection = test_db.get_collection("employees")
    create_employee(collection, new_employee)

    recommended_employee = get_recommended_employee(collection, employee_request)
    assert recommended_employee["name"] == new_employee.name
    assert recommended_employee["style"] == new_employee.style


def test_get_recommended_employee_no_match(test_db, employee_request):
    """
    Test case for getting a recommended employee with no matching employee in the database.
    """
    collection = test_db.get_collection("employees")
    recommended_employee = get_recommended_employee(collection, employee_request)
    assert recommended_employee is None


def test_get_recommended_employee_invalid_time(test_db, new_employee):
    """
    Test case for getting a recommended employee with invalid time.
    """
    collection = test_db.get_collection("employees")
    create_employee(collection, new_employee)

    request = EmployeeRequest(
        style="Test Style",
        vegetarian=True,
        open_now=True
    )

    # Manually change the current time to be outside of the open hours
    request.open_now = True
    request.current_time = "23:00"  # employee closes at 22:00

    recommended_employee = get_recommended_employee(collection, request)
    assert recommended_employee is None
