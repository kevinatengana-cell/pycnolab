import tempfile
import unittest
from pathlib import Path

from pycnolab_engine import _publier_port


class PortFileTests(unittest.TestCase):
    def test_publie_le_port_dans_un_fichier_lisible(self):
        with tempfile.TemporaryDirectory() as dossier:
            fichier = Path(dossier) / "port"

            _publier_port(54321, fichier)

            self.assertEqual(fichier.read_text(encoding="ascii").strip(), "54321")
            self.assertFalse(fichier.with_suffix(".tmp").exists())


if __name__ == "__main__":
    unittest.main()
