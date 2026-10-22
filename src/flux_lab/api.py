from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from flux_lab.health import status

app = FastAPI(title="flux-lab")

messages_recus: set[str] = set()


class Message(BaseModel):
    id: str = Field(min_length=1)
    type: str = Field(min_length=1)
    payload: dict[str, Any]


@app.get("/health")
def health() -> dict[str, str]:
    return status()


@app.post("/messages", status_code=202)
def recevoir_message(message: Message) -> dict[str, str]:
    if message.id in messages_recus:
        raise HTTPException(status_code=409, detail="message déjà reçu")
    messages_recus.add(message.id)
    return {"id": message.id}
