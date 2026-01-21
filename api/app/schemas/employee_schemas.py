from pydantic import BaseModel

class EmployeeRequest(BaseModel):
    image: str = None
    name: str = None
    department: str = None
    email: str = None
    phone: str = None

class EmployeeCreate(BaseModel):
    image: str = None
    name: str = None
    department: str = None
    email: str = None
    phone: str = None
