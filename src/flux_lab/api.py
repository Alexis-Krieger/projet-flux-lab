import sqlite3
from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from flux_lab.health import status
from flux_lab.logs import configurer
from flux_lab.store import enregistrer, stockage_disponible

app = FastAPI(title="flux-lab")
journal = configurer()


class Message(BaseModel):
    id: str = Field(min_length=1)
    type: str = Field(min_length=1)
    payload: dict[str, Any]


@app.get("/health")
def health() -> dict[str, str]:
    return status()


@app.get("/ready")
def ready() -> dict[str, str]:
    if not stockage_disponible():
        journal.error("stockage_indisponible")
        raise HTTPException(status_code=503, detail="stockage indisponible")
    return {"status": "ready"}


@app.post("/messages", status_code=202)
def recevoir_message(message: Message) -> dict[str, str]:
    champs = {"id": message.id, "type": message.type}
    try:
        nouveau = enregistrer(message.id)
    except sqlite3.Error as erreur:
        champs_erreur = {**champs, "erreur": type(erreur).__name__, "detail": str(erreur)}
        journal.error("erreur_stockage", extra={"champs": champs_erreur})
        raise HTTPException(status_code=503, detail="stockage indisponible") from erreur
    if not nouveau:
        journal.warning("message_doublon", extra={"champs": champs})
        raise HTTPException(status_code=409, detail="message déjà reçu")
    journal.info("message_recu", extra={"champs": champs})
    return {"id": message.id}
