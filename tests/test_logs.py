import json
import logging
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from flux_lab.api import app
from flux_lab.logs import JsonFormatter

client = TestClient(app)


def test_formatter_encode_les_retours_a_la_ligne() -> None:
    record = logging.makeLogRecord(
        {
            "name": "flux_lab",
            "levelno": logging.INFO,
            "levelname": "INFO",
            "msg": "evt",
            "champs": {"id": "a\nb"},
        }
    )
    sortie = JsonFormatter().format(record)
    assert "\n" not in sortie
    assert json.loads(sortie)["id"] == "a\nb"


def test_le_payload_n_est_jamais_journalise(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    monkeypatch.setenv("FLUX_LAB_DB", str(tmp_path / "logs.db"))
    message = {"id": "x-1", "type": "commande", "payload": {"carte": "4111-SECRET"}}
    with caplog.at_level(logging.INFO, logger="flux_lab"):
        client.post("/messages", json=message)
    sorties = [JsonFormatter().format(r) for r in caplog.records if r.name == "flux_lab"]
    assert sorties
    assert all("4111-SECRET" not in sortie for sortie in sorties)
