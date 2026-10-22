from fastapi.testclient import TestClient

from flux_lab.api import app

client = TestClient(app)


def test_health_retourne_ok() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
