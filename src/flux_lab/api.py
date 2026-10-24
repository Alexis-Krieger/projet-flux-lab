from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from flux_lab.health import status
from flux_lab.store import enregistrer

app = FastAPI(title="flux-lab")


class Message(BaseModel):
    id: str = Field(min_length=1)
    type: str = Field(min_length=1)
    payload: dict[str, Any]


@app.get("/health")
def health() -> dict[str, str]:
    return status()


@app.post("/messages", status_code=202)
def recevoir_message(message: Message) -> dict[str, str]:
    if not enregistrer(message.id):
        raise HTTPException(status_code=409, detail="message déjà reçu")
    return {"id": message.id}
