from flux_lab.health import status


def test_status_is_ok() -> None:
    assert status() == {"status": "ok"}
    
