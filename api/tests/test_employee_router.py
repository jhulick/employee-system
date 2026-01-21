import pytest
from app.schemas.employee_schemas import EmployeeCreate, EmployeeRequest

@pytest.fixture
def new_employee():
    """
    Fixture to create a new employee object for testing.
    """
    return {
        "name": "Test employee",
        "style": "Test Style",
        "address": "Test Address",
        "vegetarian": True,
        "open_hour": "10:00",
        "close_hour": "22:00"
    }

@pytest.fixture
def employee_request():
    """
    Fixture to create a employee request object for testing recommendations.
    """
    return {
        "style": "Test Style",
        "vegetarian": True,
        "open_now": True
    }


def test_add_employee(test_app, test_db, new_employee):
    """
    Test case for adding a new employee.
    """
    response = test_app.post("/employees", json=new_employee)
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == new_employee["name"]
    assert data["style"] == new_employee["style"]


def test_add_employee_invalid_data(test_app):
    """
    Test case for adding a new employee with invalid data.
    """
    invalid_employee = {
        "name": "Invalid employee",
        "style": "Invalid Style",
        "address": "Invalid Address",
        "vegetarian": "Yes",  # Should be a boolean
        "open_hour": "10:00",
        "close_hour": "22:00"
    }
    response = test_app.post("/employees", json=invalid_employee)
    assert response.status_code == 422




