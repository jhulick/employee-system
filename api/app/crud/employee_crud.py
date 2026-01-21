from datetime import datetime


def get_employees(collection, request):
    """
    Fetches employees based on the given request criteria.

    :param collection: MongoDB's collection of employees.
    :param request: Request object containing search criteria.
    :return: Recommended employee or None if no match found.
    """
    query = {}
    if request.style:
        query["style"] = request.style
    if request.vegetarian is not None:
        query["vegetarian"] = request.vegetarian
    if request.open_now:
        current_time = str(datetime.now().time())
        query["open_hour"] = {"$lte": current_time}
        query["close_hour"] = {"$gte": current_time}

    return collection.find_one(query)


def create_employee(collection, employee):
    """
    Creates a new employee entry in the database.

    :param collection: MongoDB's collection of employees.
    :param employee: Employee object containing employee details.
    :return: Created employee without the MongoDB ID field.
    """
    new_employee = {
        "name": employee.name,
        "style": employee.style,
        "address": employee.address,
        "vegetarian": employee.vegetarian,
        "open_hour": employee.open_hour,
        "close_hour": employee.close_hour
    }
    result = collection.insert_one(new_employee)
    return collection.find_one({"_id": result.inserted_id}, {'_id': 0})
