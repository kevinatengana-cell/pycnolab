"""
Outils d'analyse de courbe réutilisables par n'importe quel essai
(traction, compression, flexion...).

Ces fonctions sont volontairement "aveugles" au contexte métier : elles
prennent des points de mesure et rendent un nombre, sans rien savoir de
l'essai qui les appelle. C'est ce qui permet de les partager entre
traction.py, compression.py, flexion.py... sans dupliquer de code.
"""

from moteur_python.modeles.models import PointCourbe


def regression_lineaire(points_xy: list[tuple[float, float]]) -> float | None:
    """Pente (moindres carrés) d'un nuage de points, ou None si pas assez
    de points ou si les points sont alignés verticalement (dénominateur nul)."""
    n = len(points_xy)
    if n < 2:
        return None
    xs = [p[0] for p in points_xy]
    ys = [p[1] for p in points_xy]
    moy_x = sum(xs) / n
    moy_y = sum(ys) / n
    numerateur = sum((x - moy_x) * (y - moy_y) for x, y in zip(xs, ys))
    denominateur = sum((x - moy_x) ** 2 for x in xs)
    if denominateur == 0:
        return None
    return numerateur / denominateur


def module_depuis_courbe(
    points_courbe: list[PointCourbe],
    section_mm2: float,
    longueur_mm: float,
    contrainte_rupture_mpa: float,
    seuil_zone_elastique: float = 0.5,
) -> float | None:
    """
    Calcule le module d'élasticité (Young, flexion, etc.) à partir d'une
    courbe force/déplacement.

    Principe : on ne garde que les points de la "zone élastique"
    (approximée ici comme les points sous `seuil_zone_elastique` fois la
    contrainte de rupture, 50% par défaut), puis on calcule la pente
    contrainte/déformation sur cette zone via régression linéaire.

    Paramètres :
        points_courbe          : liste de points {force_newton, deplacement_mm}
        section_mm2             : section de l'échantillon (déjà calculée
                                   en amont par l'appelant, via
                                   Echantillon.section_mm2())
        longueur_mm             : longueur initiale de l'échantillon (ou
                                   distance entre appuis pour la flexion)
        contrainte_rupture_mpa   : contrainte à rupture déjà calculée par
                                   l'appelant
        seuil_zone_elastique     : fraction de la contrainte de rupture en
                                   dessous de laquelle un point est
                                   considéré comme "élastique" (0.5 = 50%)

    Retourne le module en MPa, ou None si moins de 2 points fournis.
    """
    if len(points_courbe) < 2:
        return None

    points_sigma_epsilon = []
    for pt in points_courbe:
        sigma = pt.force_newton / section_mm2
        epsilon = pt.deplacement_mm / longueur_mm  # sans unité (pas en %) pour un module en MPa
        if sigma <= seuil_zone_elastique * contrainte_rupture_mpa:
            points_sigma_epsilon.append((epsilon, sigma))

    return regression_lineaire(points_sigma_epsilon)


def module_zone_deformation(
    points_deformation_contrainte: list[tuple[float, float]],
    borne_inf: float = 0.0005,  # 0.05%
    borne_sup: float = 0.0025,  # 0.25%
) -> float | None:
    """
    Variante de calcul du module d'élasticité : régression sur une plage
    de déformation FIXE (méthode courante dans certaines normes ISO/ASTM
    pour les métaux et composites), plutôt que sur un pourcentage de la
    contrainte de rupture.

    A utiliser à la place de module_depuis_courbe si la norme du labo
    l'exige explicitement - à confirmer avec eux avant de basculer
    traction.py dessus. Les deux méthodes coexistent tant que ce n'est
    pas tranché.

    points_deformation_contrainte : liste de (deformation, contrainte_mpa),
    typiquement obtenue via outils.courbe.courbe_contrainte_deformation().
    """
    points_filtres = [
        (eps, sigma) for eps, sigma in points_deformation_contrainte
        if borne_inf <= eps <= borne_sup
    ]
    return regression_lineaire(points_filtres)