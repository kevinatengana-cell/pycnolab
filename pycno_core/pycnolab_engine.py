"""Point d'entrée du backend PycnoLab, lancé par Flutter ou Python embarqué.

Annonce « PORT_BOUND:<port> » sur stdout. Tous les arguments sont optionnels.
"""
from __future__ import annotations

import argparse
import asyncio
import logging
import multiprocessing
import os
import socket
import sys
from datetime import datetime
from pathlib import Path

log = logging.getLogger("pycnolab.engine")


def default_data_dir() -> Path:
    base = os.environ.get("LOCALAPPDATA") or str(Path.home())
    name = "PycnoLab" if getattr(sys, "frozen", False) else "PycnoLab_dev"
    return Path(base) / name


def _ensure_streams(log_file: Path) -> None:
    if sys.stdout is not None and sys.stderr is not None:
        return

    stream = open(log_file, "a", encoding="utf-8", buffering=1)
    if sys.stdout is None:
        sys.stdout = stream
    if sys.stderr is None:
        sys.stderr = stream


class _QuietAccess(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        msg = record.getMessage()
        return "/health" not in msg and "/internal/heartbeat" not in msg


def _setup_logging(log_file: Path) -> None:
    fmt = logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s")
    root = logging.getLogger()
    root.setLevel(logging.INFO)
    for h in list(root.handlers):
        h.close()
        root.removeHandler(h)
    fh = logging.FileHandler(log_file, encoding="utf-8")
    fh.setFormatter(fmt)
    root.addHandler(fh)
    logging.getLogger("uvicorn.access").addFilter(_QuietAccess())


def _publier_port(port: int, fichier: Path) -> None:
    temporaire = fichier.with_suffix(fichier.suffix + ".tmp")
    temporaire.write_text(f"{port}\n", encoding="ascii")
    temporaire.replace(fichier)


async def _run(args: argparse.Namespace, data_dir: Path) -> int:
    import uvicorn

    from moteur_python.api.main import app

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.bind(("127.0.0.1", args.port))
    sock.listen(128)
    port = sock.getsockname()[1]

    config = uvicorn.Config(
        app, host="127.0.0.1", port=port, log_config=None, lifespan="auto"
    )
    server = uvicorn.Server(config)
    serve_task = asyncio.create_task(server.serve(sockets=[sock]))

    while not server.started and not serve_task.done():
        await asyncio.sleep(0.05)
    if not server.started:
        await serve_task
        log.error("Le serveur n'a pas pu démarrer.")
        return 3

    log.info("Moteur prêt sur 127.0.0.1:%d (données : %s)", port, data_dir)
    if args.port_file:
        _publier_port(port, Path(args.port_file))
    print(f"PORT_BOUND:{port}", flush=True)

    await serve_task
    return 0


def main(argv: list[str] | None = None) -> int:
    local_app_data = os.environ.get("LOCALAPPDATA") or str(Path.home())
    log_file = Path(local_app_data) / "PycnoLab" / "logs" / "backend.log"
    try:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        _ensure_streams(log_file)
        _setup_logging(log_file)
        log.info("Démarrage du moteur PycnoLab")
        log.info("Version Python : %s", sys.version.replace("\n", " "))
        log.info("Exécutable : %s", sys.executable)
        log.info("Date : %s", datetime.now().astimezone().isoformat())

        parser = argparse.ArgumentParser(prog="pycnolab_engine")
        parser.add_argument("--port", type=int, default=0, help="0 = port libre")
        parser.add_argument("--data-dir", default=None)
        parser.add_argument("--port-file", default=None)
        args, unknown = parser.parse_known_args(argv)

        data_dir = Path(args.data_dir) if args.data_dir else default_data_dir()
        (data_dir / "logs").mkdir(parents=True, exist_ok=True)
        if unknown:
            log.warning("Arguments ignorés : %s", unknown)

        os.environ["PYCNOLAB_DATA_DIR"] = str(data_dir)
        return asyncio.run(_run(args, data_dir))
    except Exception:
        logging.getLogger("pycnolab.engine").exception(
            "Échec du démarrage du moteur"
        )
        return 1


if __name__ == "__main__":
    multiprocessing.freeze_support()
    sys.exit(main())