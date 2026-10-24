import os
import sqlite3
from pathlib import Path


def chemin_base() -> Path:
    return Path(os.environ.get("FLUX_LAB_DB", "flux_lab.db"))


def _connexion() -> sqlite3.Connection:
    connexion = sqlite3.connect(chemin_base())
    connexion.execute("CREATE TABLE IF NOT EXISTS messages_recus (id TEXT PRIMARY KEY)")
    return connexion


def enregistrer(message_id: str) -> bool:
    """Renvoie True si le message est nouveau, False si c'est un doublon."""
    connexion = _connexion()
    try:
        with connexion:
            connexion.execute("INSERT INTO messages_recus (id) VALUES (?)", (message_id,))
    except sqlite3.IntegrityError:
        return False
    finally:
        connexion.close()
    return True
