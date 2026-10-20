from flux_lab.health import status


def test_status_is_ok():
    assert status() == {"status": "ok"}

