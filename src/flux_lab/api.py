from fastapi import FastAPI

from flux_lab.health import status

app = FastAPI(title="flux-lab")


@app.get("/health")
def health() -> dict[str, str]:
    return status()
