import unittest
from unittest.mock import patch

from moteur_python.api.backend_lifecycle import BackendLifecycle
from pycnolab_engine import _arguments


class BackendLifecycleTests(unittest.TestCase):
    def test_arguments_requis_et_port_valide(self):
        arguments = _arguments(['--port', '8765', '--data-dir', 'C:/pycnolab-data'])
        self.assertEqual(arguments.port, 8765)
        self.assertEqual(str(arguments.data_dir), 'C:\\pycnolab-data')

    def test_port_hors_limite_est_refuse(self):
        with self.assertRaises(SystemExit):
            _arguments(['--port', '65536', '--data-dir', 'C:/pycnolab-data'])

    def test_heartbeat_expire_apres_dix_secondes_sans_signal(self):
        lifecycle = BackendLifecycle()
        with patch(
            'moteur_python.api.backend_lifecycle.time.monotonic',
            side_effect=(100.0, 109.9, 110.0),
        ):
            lifecycle.mark_ready()
            self.assertFalse(lifecycle.heartbeat_expired(timeout_seconds=10))
            self.assertTrue(lifecycle.heartbeat_expired(timeout_seconds=10))


if __name__ == '__main__':
    unittest.main()
