from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from flux_lab.api import app

client = TestClient(app)

MESSAGE = {"id": "abc-1", "type": "commande", "payload": {"montant": 42}}


@pytest.fixture(autouse=True)
def base_temporaire(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("FLUX_LAB_DB", str(tmp_path / "test.db"))


def test_health_retourne_ok() -> None:
    response = client.get("/health")
    body = response.json()
    assert response.status_code == 200
    assert body["status"] == "ok"
    assert "version" in body


def test_message_valide_est_accepte() -> None:
    response = client.post("/messages", json=MESSAGE)
    assert response.status_code == 202
    assert response.json() == {"id": "abc-1"}


def test_message_sans_type_est_rejete() -> None:
    response = client.post("/messages", json={"id": "abc-1", "payload": {}})
    assert response.status_code == 422


def test_message_avec_id_vide_est_rejete() -> None:
    response = client.post(
        "/messages",
        json={"id": "", "type": "commande", "payload": {}},
    )
    assert response.status_code == 422


def test_message_en_double_est_refuse() -> None:
    premier = client.post("/messages", json=MESSAGE)
    second = client.post("/messages", json=MESSAGE)
    assert premier.status_code == 202
    assert second.status_code == 409


def test_ready_quand_le_stockage_fonctionne() -> None:
    response = client.get("/ready")
    assert response.status_code == 200
    assert response.json() == {"status": "ready"}


def test_ready_indisponible_si_le_stockage_est_casse(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("FLUX_LAB_DB", str(tmp_path / "absent" / "x.db"))
    response = client.get("/ready")
    assert response.status_code == 503


def test_message_renvoie_503_sans_detail_interne(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("FLUX_LAB_DB", str(tmp_path / "absent" / "x.db"))
    response = client.post("/messages", json=MESSAGE)
    assert response.status_code == 503
    assert response.json() == {"detail": "stockage indisponible"}
