"""
Calculs liés à l'élasticité (Limite élastique, Yield Strength).
"""
from typing import Optional
from moteur_python.modeles.models import PointCourbe
from moteur_python.calculs.outils.courbe import courbe_contrainte_deformation

def limite_elastique_offset(
    points_courbe: list[PointCourbe],
    section_mm2: float,
    longueur_mm: float,
    module_young_mpa: float,
    offset_pourcent: float = 0.2
) -> Optional[float]:
    """
    Calcule la limite élastique (Yield Strength) par la méthode de l'offset (0.2% par défaut).
    Retourne la contrainte en MPa à l'intersection.
    """
    if len(points_courbe) < 2 or module_young_mpa is None or module_young_mpa <= 0:
        return None

    # Obtenir la courbe (déformation, contrainte)
    points_bruts = [(p.force_newton, p.deplacement_mm) for p in points_courbe]
    courbe_sd = courbe_contrainte_deformation(points_bruts, section_mm2, longueur_mm)
    
    offset_strain = offset_pourcent / 100.0
    
    # Trier par déformation croissante
    courbe_sd = sorted(courbe_sd, key=lambda x: x[0])
    
    for i in range(1, len(courbe_sd)):
        eps1, sig1 = courbe_sd[i-1]
        eps2, sig2 = courbe_sd[i]
        
        # Valeurs sur la droite d'offset (sigma = E * (epsilon - offset))
        sig_droite1 = module_young_mpa * (eps1 - offset_strain)
        sig_droite2 = module_young_mpa * (eps2 - offset_strain)
        
        diff1 = sig1 - sig_droite1
        diff2 = sig2 - sig_droite2
        
        # On cherche quand la courbe croise la droite (la courbe passe sous la droite)
        if diff1 >= 0 and diff2 <= 0:
            if eps2 != eps1:
                m_courbe = (sig2 - sig1) / (eps2 - eps1)
                if module_young_mpa != m_courbe:
                    eps_inter = (sig1 - m_courbe * eps1 + module_young_mpa * offset_strain) / (module_young_mpa - m_courbe)
                    sig_inter = module_young_mpa * (eps_inter - offset_strain)
                    return sig_inter
            return sig2 # Fallback
            
    return None
