from fastapi import FastAPI
from app.routers import employee_router
from app.middleware import middleware

app = FastAPI()

#Include middleware for logging requests
app.add_middleware(RequestLoggerMiddleware)

# Include routers
app.include_router(employee_router.router)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
