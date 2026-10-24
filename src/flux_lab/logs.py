import json
import logging
import sys
from datetime import UTC, datetime
from typing import Any


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        entree: dict[str, Any] = {
            "ts": datetime.now(UTC).isoformat(timespec="seconds"),
            "niveau": record.levelname,
            "evenement": record.getMessage(),
        }
        entree.update(getattr(record, "champs", {}))
        return json.dumps(entree, ensure_ascii=False)


def configurer() -> logging.Logger:
    logger = logging.getLogger("flux_lab")
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(JsonFormatter())
        logger.addHandler(handler)
        logger.setLevel(logging.INFO)
    return logger
