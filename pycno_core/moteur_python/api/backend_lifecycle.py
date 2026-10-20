"""Process-local heartbeat state for the desktop API server."""

import threading
import time


class BackendLifecycle:
    def __init__(self):
        self._lock = threading.Lock()
        self._last_heartbeat = None

    def mark_ready(self):
        self.beat()

    def beat(self):
        with self._lock:
            self._last_heartbeat = time.monotonic()

    def heartbeat_expired(self, timeout_seconds=10):
        with self._lock:
            last_heartbeat = self._last_heartbeat
        return (
            last_heartbeat is not None
            and time.monotonic() - last_heartbeat >= timeout_seconds
        )


backend_lifecycle = BackendLifecycle()
