from importlib.metadata import version


def status() -> dict[str, str]:
    """État minimal du service, base du futur endpoint /health."""
    return {"status": "ok", "version": version("flux-lab")}
