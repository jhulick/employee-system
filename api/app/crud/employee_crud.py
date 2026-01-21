from datetime import datetime


def get_employees(collection):
    """
    Fetches employees based on the given request criteria.

    :param collection: MongoDB's collection of employees.
    :return: Employees or no matches found.
    """

    return collection.all()

def create_employee(collection, employee):
    """
    Creates a new employee entry in the database.

    :param collection: MongoDB's collection of employees.
    :param employee: Employee object containing employee details.
    :return: Created employee without the MongoDB ID field.
    """
    new_employee = {
        "name": employee.name,
        "image": employee.image,
        "department": employee.department,
        "email": employee.email,
        "phone": employee.phone
    }
    result = collection.insert_one(new_employee)
    return collection.find_one({"_id": result.inserted_id}, {'_id': 0})
