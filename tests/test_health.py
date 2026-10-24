from flux_lab.health import status


def test_status_is_ok() -> None:
    result = status()
    assert result["status"] == "ok"
    assert result["version"]
