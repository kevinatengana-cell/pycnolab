"""
Interface générique du moteur de calcul.
Chaque nouvel essai (compression, flexion...) implémente cette interface.
C'est ce contrat qui garantit que le reste de l'app (formulaire, export
Excel/PDF) n'a jamais besoin d'être modifié quand on ajoute un essai.
"""

from abc import ABC, abstractmethod

from moteur_python.modeles.models import Gamme, ResultatGamme


class MoteurCalcul(ABC):
    @abstractmethod
    def calculer(self, gamme: Gamme) -> ResultatGamme:
        ...
