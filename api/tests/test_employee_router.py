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


def test_get_recommendation(test_app, test_db, new_employee, employee_request):
    """
    Test case for getting a employee recommendation.
    """
    # First, add a employee to the database
    test_app.post("/employees", json=new_employee)

    # Then, check for a employee recommendation
    response = test_app.post("/recommendation", json=employee_request)
    assert response.status_code == 200
    data = response.json()["employeeRecommendation"]
    assert data["name"] == new_employee["name"]
    assert data["style"] == new_employee["style"]


def test_get_recommendation_no_match(test_app):
    """
    Test case for getting a employee recommendation with no matching employee.
    """
    request = {
        "style": "Nonexistent Style",
        "vegetarian": False,
        "open_now": True
    }
    response = test_app.post("/recommendation", json=request)
    assert response.status_code == 404
    assert response.json()["detail"] == "No matching employee found"


def test_get_recommendation_invalid_data(test_app):
    """
    Test case for getting a employee recommendation with invalid data.
    """
    invalid_request = {
        "style": "Test Style",
        "vegetarian": "Yes",  # Should be a boolean
        "open_now": True
    }
    response = test_app.post("/recommendation", json=invalid_request)
    assert response.status_code == 422
