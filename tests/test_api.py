from fastapi.testclient import TestClient

from flux_lab.api import app

client = TestClient(app)


def test_health_retourne_ok() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_message_valide_est_accepte() -> None:
    response = client.post(
        "/messages",
        json={"id": "abc-1", "type": "commande", "payload": {"montant": 42}},
    )
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
