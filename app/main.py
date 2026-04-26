from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator
import uvicorn

app = FastAPI(title="Hello World Service")

Instrumentator().instrument(app).expose(app)


@app.get("/")
async def root():
    return {"message": "Hello World"}


@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080)
