#!/usr/bin/env python3
"""
extract_norm_pdf.py
--------------------
Pipeline d'extraction 100% local et déterministe (sans LLM) permettant de lire
N'IMPORTE QUEL PDF de norme d'essai mécanique (ISO, AFNOR, ASTM, DIN, EN, ...)
et de produire un JSON de pré-remplissage exploitable par l'éditeur no-code
PycnoLab (Flutter).

Architecture (voir procédure opératoire PycnoLab, Phase 1) :
    Couche 1 - Extraction brute agnostique (texte + tables + positions x/y)
    Couche 2 - Détection par patterns génériques (regex + mots-clés flous)
    Couche 3 - Reconstruction de tableaux sans bordures (clustering x/y)
    Couche 4 - Scoring de confiance par champ
    Couche 5 - Sortie JSON structurée (schema_draft.json)

Aucune dépendance réseau, aucun modèle de langage : le script fait le maximum,
l'opérateur du laboratoire effectue la validation finale dans l'application.

Usage:
    python extract_norm_pdf.py --input norms/ASTM_D3039.pdf --output schema_draft.json
    python extract_norm_pdf.py --input norms/ASTM_D3039.pdf --output schema_draft.json --verbose
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import statistics
import sys
import unicodedata
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

try:
    import pdfplumber
except ImportError:
    pdfplumber = None

try:
    import pytesseract
except ImportError:
    pytesseract = None


# ============================================================================
# CONSTANTES ET DICTIONNAIRES DE RÉFÉRENCE
# ============================================================================

# Bibliothèque de motifs de codes de normes. Volontairement large et
# indépendante de la position dans le document : on cherche partout le
# premier motif plausible, jamais un unique format figé.
NORM_CODE_PATTERNS = [
    r"\bNF\s?EN\s?ISO\s?\d{3,6}(?:[\-–/]\d+)?\b",
    r"\bNF\s?EN\s?\d{3,6}(?:[\-–/]\d+)?\b",
    r"\bNF\s?ISO\s?\d{3,6}(?:[\-–/]\d+)?\b",
    r"\bNF\s?[A-Z]\s?\d{2,3}[\-–]\d{3,4}\b",
    r"\bEN\s?ISO\s?\d{3,6}(?:[\-–/]\d+)?\b",
    r"\bEN\s?\d{3,6}(?:[\-–/]\d+)?\b",
    r"\bISO\s?\d{3,6}(?:[\-–/]\d+)?\b",
    r"\bASTM\s?[A-Z]\s?\d{2,5}(?:[\-–/][A-Za-z0-9]+)?\b",
    r"\bDIN\s?EN\s?\d{3,6}\b",
    r"\bDIN\s?\d{3,6}\b",
    r"\bBS\s?EN\s?\d{3,6}\b",
    r"\bASME\s?[A-Z0-9.\-]{3,10}\b",
]

# Dictionnaire d'unités scientifiques reconnues, du plus spécifique au plus
# générique (évite qu'un "m" isolé matche avant "mm²").
KNOWN_UNITS = [
    "mm²", "cm²", "m²", "mm³", "cm³", "m³",
    "N/mm²", "N/mm", "kN/mm²",
    "MPa", "GPa", "kPa", "Pa",
    "kN", "daN", "mN", "N",
    "kg/m³", "g/cm³",
    "mm/min", "mm/s", "m/s",
    "°C", "°K", "°",
    "mm", "cm", "dm", "m",
    "kg", "g", "mg", "t",
    "s", "min", "h",
    "%", "J", "kJ",
]
# Tri par longueur décroissante pour matcher les unités composées en premier
KNOWN_UNITS_SORTED = sorted(set(KNOWN_UNITS), key=len, reverse=True)

# Mots-clés (avec variantes/synonymes) utilisés pour localiser les sections
# clés du document, indépendamment du plan exact de la norme source.
SECTION_KEYWORDS = {
    "header": [
        "objet", "domaine d'application", "domaine dapplication", "scope",
        "portee", "portée", "introduction",
    ],
    "geometry": [
        "eprouvette", "éprouvette", "eprouvettes", "specimen", "spécimen",
        "specimens", "dimensions", "geometrie", "géométrie", "forme et dimensions",
        "test piece", "test specimen",
    ],
    "procedure": [
        "mode operatoire", "mode opératoire", "procedure", "procédure",
        "conditions d'essai", "conditions dessai", "deroulement", "déroulement",
        "test procedure", "methode d'essai", "méthode d'essai",
    ],
    "results": [
        "expression des resultats", "expression des résultats",
        "calcul", "calculs", "resultats", "résultats", "formule", "formules",
        "expression of results", "calculation",
    ],
}

# Variables physiques usuelles avec leurs synonymes, pour aider à typer les
# libellés détectés dans les tableaux (purement indicatif, n'exclut rien).
COMMON_VARIABLES_HINTS = {
    "largeur": ["largeur", "width", "b"],
    "epaisseur": ["epaisseur", "épaisseur", "thickness", "e"],
    "diametre": ["diametre", "diamètre", "diameter", "d"],
    "longueur": ["longueur", "length", "l0", "lo"],
    "section": ["section", "aire", "area", "s0", "so"],
    "force_max": ["force maximale", "force max", "charge maximale", "fmax", "f max"],
    "masse": ["masse", "mass", "poids", "weight"],
    "vitesse": ["vitesse", "speed", "rate"],
    "temperature": ["temperature", "température", "temperature d'essai"],
}


def strip_accents(text: str) -> str:
    """Retire les accents pour faciliter les comparaisons floues."""
    return "".join(
        c for c in unicodedata.normalize("NFKD", text) if not unicodedata.combining(c)
    )


def normalize(text: str) -> str:
    return strip_accents(text or "").lower().strip()


def slugify(text: str) -> str:
    """Convertit un libellé en clé technique snake_case (ex: 'Force maximale à la rupture' -> 'force_maximale_a_la_rupture')."""
    text = normalize(text)
    text = re.sub(r"[^a-z0-9]+", "_", text)
    text = re.sub(r"_+", "_", text).strip("_")
    return text or "champ"


# ============================================================================
# STRUCTURES DE DONNÉES
# ============================================================================

@dataclass
class ExtractedField:
    key: str
    label: str
    type: str = "decimal"
    unit: Optional[str] = None
    required: bool = True
    source: str = "regex"          # regex | table_detectee | reconstruction_xy
    confidence: str = "moyenne"    # haute | moyenne | basse
    raw_text: str = ""
    symbol: Optional[str] = None
    page_number: Optional[int] = None


@dataclass
class ExtractedFormula:
    output_key: str
    label: str
    formula: str
    unit: Optional[str] = None
    confidence: str = "moyenne"
    status: str = "needs_review"
    raw_detected_formula: str = ""


@dataclass
class ExtractionResult:
    norm_code: Optional[str] = None
    norm_code_confidence: str = "basse"
    title: Optional[str] = None
    material_hint: Optional[str] = None
    fields: list[ExtractedField] = field(default_factory=list)
    formulas: list[ExtractedFormula] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)


# ============================================================================
# COUCHE 1 - EXTRACTION BRUTE AGNOSTIQUE
# ============================================================================

def extract_raw(pdf_path: Path, verbose: bool = False) -> dict[str, Any]:
    if pdfplumber is None:
        raise RuntimeError("Le module pdfplumber est requis pour extraire les PDF.")
    """
    Extrait, sans aucune hypothèse de mise en page :
      - le texte complet, page par page
      - les tables détectées automatiquement par pdfplumber
      - les mots avec leurs coordonnées (x0, x1, top, bottom) pour permettre
        une reconstruction manuelle des tableaux en Couche 3.
    """
    pages_data = []
    ocr_failed_binary = False
    with pdfplumber.open(str(pdf_path)) as pdf:
        for page_number, page in enumerate(pdf.pages, start=1):
            text = page.extract_text() or ""
            words = page.extract_words(use_text_flow=False, keep_blank_chars=False)
            tables = []
            
            # Fallback OCR if no text extracted and pytesseract is available
            if not text.strip():
                if pytesseract is None:
                    ocr_failed_binary = True
                else:
                    try:
                        img = page.to_image(resolution=150)
                        pil_img = img.original
                        text = pytesseract.image_to_string(pil_img) or ""
                        ocr_data = pytesseract.image_to_data(pil_img, output_type=pytesseract.Output.DICT)
                        ocr_words = []
                        for i in range(len(ocr_data["text"])):
                            w_text = ocr_data["text"][i].strip()
                            if w_text:
                                l_val = ocr_data["left"][i]
                                t_val = ocr_data["top"][i]
                                w_val = ocr_data["width"][i]
                                h_val = ocr_data["height"][i]
                                ocr_words.append({
                                    "x0": l_val,
                                    "x1": l_val + w_val,
                                    "top": t_val,
                                    "bottom": t_val + h_val,
                                    "text": w_text
                                })
                        if ocr_words:
                            words = ocr_words
                    except Exception as ocr_err:
                        ocr_failed_binary = True
                        if verbose:
                            print(f"  [page {page_number}] Échec OCR : {ocr_err}", file=sys.stderr)

            try:
                for table in page.extract_tables():
                    # Nettoyage basique des cellules (None -> "")
                    cleaned = [
                        [(cell or "").strip() for cell in row] for row in table
                    ]
                    if any(any(c for c in row) for row in cleaned):
                        tables.append(cleaned)
            except Exception as exc:  # pdfplumber peut échouer sur des PDF corrompus
                if verbose:
                    print(f"  [page {page_number}] extraction de table échouée: {exc}", file=sys.stderr)

            pages_data.append(
                {
                    "page_number": page_number,
                    "text": text,
                    "words": words,
                    "tables": tables,
                }
            )
            if verbose:
                print(
                    f"  [page {page_number}] {len(text)} caractères, "
                    f"{len(words)} mots, {len(tables)} table(s) détectée(s)",
                    file=sys.stderr,
                )

    full_text = "\n".join(p["text"] for p in pages_data)
    return {"pages": pages_data, "full_text": full_text, "ocr_failed_binary": ocr_failed_binary}


# ============================================================================
# COUCHE 2 - DÉTECTION PAR PATTERNS GÉNÉRIQUES
# ============================================================================

def detect_norm_code(full_text: str) -> tuple[Optional[str], str]:
    """Cherche un code de norme parmi une bibliothèque de formats. Retourne
    (code, confiance). Priorité aux motifs les plus spécifiques."""
    for pattern in NORM_CODE_PATTERNS:
        match = re.search(pattern, full_text, flags=re.IGNORECASE)
        if match:
            code = re.sub(r"\s+", " ", match.group(0).strip())
            return code, "haute"
    return None, "basse"


FORBIDDEN_TITLE_KEYWORDS = [
    "json", "parser", "workflow", "extraction", "amorce", "draft", "guide",
    "procedure", "creation", "ingestion", "documentation", "test", "verification",
    "simulation", "github", "gitlab", "pipeline"
]


def is_valid_title(line: str) -> bool:
    norm_line = normalize(line)
    if any(kw in norm_line for kw in FORBIDDEN_TITLE_KEYWORDS):
        return False
    if re.match(r"^(?:\d+[.)]|[-•])\s", line):
        return False
    if "/" in line or "\\" in line or ".pdf" in norm_line or ".json" in norm_line:
        return False
    if "{" in line or "}" in line or '"' in line or "[" in line or "]" in line:
        return False
    return True


def detect_title(full_text: str, norm_code: Optional[str]) -> Optional[str]:
    """Heuristique: le titre de l'essai est souvent la ligne qui suit
    immédiatement le code de norme, ou la première ligne longue et non
    numérique du document."""
    lines = [l.strip() for l in full_text.splitlines() if l.strip()]
    if norm_code:
        for i, line in enumerate(lines[:40]):
            if norm_code.split()[0].lower() in normalize(line):
                # regarde la même ligne après le code, ou la ligne suivante
                remainder = line.replace(norm_code, "").strip(" -–:")
                # Les normes sont souvent citées dans une liste d'exemples.
                # Cette ligne ne constitue pas le titre du document.
                looks_like_reference_list = not is_valid_title(line)
                if len(remainder) > 8 and not looks_like_reference_list:
                    return remainder
                if (
                    i + 1 < len(lines)
                    and len(lines[i + 1]) > 8
                    and is_valid_title(lines[i + 1])
                ):
                    return lines[i + 1]
    # Repli : première ligne "consistante" (pas juste des chiffres/codes courts)
    for line in lines[:20]:
        letters = sum(c.isalpha() for c in line)
        if letters >= 10 and not line.isupper() and is_valid_title(line):
            return line
    for line in lines[:20]:
        if is_valid_title(line):
            return line
    return lines[0] if lines else None


def find_section_spans(pages: list[dict], verbose: bool = False) -> dict[str, list[tuple[int, int]]]:
    """
    Localise, par correspondance floue de mots-clés, les zones (page, index de
    ligne) où débutent les sections d'intérêt. Fonctionne quel que soit le
    plan exact du document source.
    """
    spans: dict[str, list[tuple[int, int]]] = defaultdict(list)
    for page in pages:
        lines = page["text"].splitlines()
        for line_idx, line in enumerate(lines):
            norm_line = normalize(line)
            if not norm_line or len(norm_line) > 120:
                continue
            for section, keywords in SECTION_KEYWORDS.items():
                for kw in keywords:
                    kw_norm = normalize(kw)
                    ratio = difflib.SequenceMatcher(None, kw_norm, norm_line).ratio()
                    if kw_norm in norm_line or ratio > 0.72:
                        spans[section].append((page["page_number"], line_idx))
                        break
    if verbose:
        for section, hits in spans.items():
            print(f"  section '{section}': {len(hits)} occurrence(s)", file=sys.stderr)
    return spans


def detect_material_hint(full_text: str) -> Optional[str]:
    """Recherche approximative d'un matériau/domaine d'application mentionné
    en tête de document (ex: 'fibres végétales', 'composites', 'béton')."""
    material_keywords = [
        "fibre végétale", "fibre naturelle", "composite", "béton", "acier",
        "polymère", "bois", "textile", "céramique", "plastique", "métal",
        "aluminium", "caoutchouc", "elastomere", "élastomère",
    ]
    norm_text = normalize(full_text[:3000])  # se limite à l'en-tête du document
    for kw in material_keywords:
        if normalize(kw) in norm_text:
            return kw
    return None


def scan_units_near(text: str) -> Optional[str]:
    """Retourne la première unité connue trouvée dans un fragment de texte."""
    for unit in KNOWN_UNITS_SORTED:
        # Bordures approximatives pour éviter de matcher "m" dans "mm" etc.
        pattern = r"(?<![A-Za-zÀ-ÿ])" + re.escape(unit) + r"(?![A-Za-zÀ-ÿ])"
        if re.search(pattern, text):
            return unit
    return None


def _is_plausible_field_table(table: list[list[str]]) -> bool:
    """Filtre les faux tableaux que pdfplumber crée parfois sur toute une page."""
    if not table or len(table) < 2:
        return False

    column_count = max((len(row) for row in table), default=0)
    if column_count < 2:
        return False

    cells = [cell.strip() for row in table for cell in row if cell and cell.strip()]
    if not cells:
        return False

    # Une page entière détectée comme tableau produit généralement une cellule
    # de plusieurs centaines de caractères, ce qui n'est pas une ligne de
    # paramètres exploitable.
    if max(map(len, cells)) > 240:
        return False

    # Longueur moyenne des cellules non vides (évite les pages de texte complet)
    avg_len = sum(len(c) for c in cells) / len(cells)
    if avg_len > 80:
        return False

    header_text = " ".join(table[0]).lower()
    has_header_hint = any(
        hint in normalize(header_text)
        for hint in (
            "designation", "libelle", "grandeur", "parametre", "variable",
            "nom", "symbole", "notation", "repere", "unite",
        )
    )
    unit_hits = sum(1 for cell in cells if scan_units_near(cell))
    return has_header_hint or unit_hits >= 1


def _page_has_plausible_field_table(page: dict) -> bool:
    return any(_is_plausible_field_table(table) for table in page["tables"])


def extract_fields_from_tables(pages: list[dict], verbose: bool = False) -> list[ExtractedField]:
    """
    Couche 2/3 combinées : exploite en priorité les tables que pdfplumber a
    su détecter nativement (bordures visibles). Le mapping des colonnes
    (Symbole / Libellé / Unité) est déduit dynamiquement par en-tête ET par
    contenu, sans supposer un ordre de colonnes fixe.
    """
    fields: list[ExtractedField] = []
    header_hints = {
        "label": ["designation", "désignation", "libelle", "libellé", "grandeur",
                  "parametre", "paramètre", "variable", "nom"],
        "symbol": ["symbole", "notation", "repere", "repère", "sigle"],
        "unit": ["unite", "unité", "unit"],
    }

    for page in pages:
        for table in page["tables"]:
            if not _is_plausible_field_table(table):
                continue
            header_row = table[0]
            col_roles: dict[int, str] = {}
            for col_idx, cell in enumerate(header_row):
                norm_cell = normalize(cell)
                for role, hints in header_hints.items():
                    if any(h in norm_cell for h in hints):
                        col_roles[col_idx] = role
                        break

            # Si aucun en-tête reconnu, on tente une heuristique de contenu :
            # la colonne contenant le plus d'unités connues = colonne "unit"
            if "unit" not in col_roles.values() and len(header_row) >= 2:
                col_unit_hits = defaultdict(int)
                for row in table[1:]:
                    for col_idx, cell in enumerate(row):
                        if cell and scan_units_near(cell):
                            col_unit_hits[col_idx] += 1
                if col_unit_hits:
                    best_col = max(col_unit_hits, key=col_unit_hits.get)
                    col_roles[best_col] = "unit"

            if "label" not in col_roles.values():
                # à défaut, on suppose que la première colonne texte "longue"
                # est le libellé
                for col_idx in range(len(header_row)):
                    if col_idx not in col_roles:
                        col_roles[col_idx] = "label"
                        break

            if not col_roles:
                continue

            for row in table[1:]:
                label = symbol = unit_val = ""
                for col_idx, role in col_roles.items():
                    if col_idx >= len(row):
                        continue
                    cell = (row[col_idx] or "").strip()
                    if role == "label" and not label:
                        label = cell
                    elif role == "symbol" and not symbol:
                        symbol = cell
                    elif role == "unit" and not unit_val:
                        unit_val = cell

                if not label and not symbol:
                    continue

                display_label = label or symbol
                if len(display_label) < 2 or len(display_label) > 100:
                    continue  # écarte le bruit / lignes vides

                detected_unit = scan_units_near(unit_val) or scan_units_near(display_label)
                key = slugify(symbol) if symbol and len(symbol) <= 6 else slugify(display_label)

                fields.append(
                    ExtractedField(
                        key=key,
                        label=display_label,
                        unit=detected_unit,
                        source="table_detectee",
                        confidence="haute" if detected_unit else "moyenne",
                        raw_text=" | ".join(filter(None, [label, symbol, unit_val])),
                        symbol=symbol or None,
                        page_number=page["page_number"],
                    )
                )
    if verbose:
        print(f"  {len(fields)} champ(s) extrait(s) via tables détectées", file=sys.stderr)
    return fields


# ============================================================================
# COUCHE 3 - RECONSTRUCTION DE TABLEAUX SANS BORDURES
# ============================================================================

def reconstruct_fields_from_words(pages: list[dict], pages_with_table_fields: set[int] = None, verbose: bool = False) -> list[ExtractedField]:
    """
    Pour les pages sans table détectée (PDF scanné, tableaux sans lignes),
    reconstruit des lignes virtuelles en regroupant les mots par proximité
    verticale (top), puis tente d'isoler un couple (libellé, unité) par ligne
    en cherchant une unité connue en fin de ligne.
    """
    if pages_with_table_fields is None:
        pages_with_table_fields = set()
    fields: list[ExtractedField] = []

    for page in pages:
        if page["page_number"] in pages_with_table_fields:
            continue  # déjà couvert par la Couche 2
        words = page["words"]
        if not words:
            continue

        # Regroupe les mots par ligne approximative (tolérance de 3px sur 'top')
        rows: list[list[dict]] = []
        for w in sorted(words, key=lambda w: (round(w["top"] / 3), w["x0"])):
            row_key = round(w["top"] / 3)
            if rows and abs(rows[-1][0]["top"] - w["top"]) <= 3:
                rows[-1].append(w)
            else:
                rows.append([w])

        for row in rows:
            row_sorted = sorted(row, key=lambda w: w["x0"])
            line_text = " ".join(w["text"] for w in row_sorted)
            norm_line = normalize(line_text)

            # Filtre : lignes trop courtes/longues, ressemblant à des phrases
            # (>12 mots), ou contenant un signe '=' (ce sont des équations de
            # calcul, pas des variables d'entrée à saisir par le technicien)
            if len(line_text) < 3 or len(row_sorted) > 12:
                continue
            if "=" in line_text:
                continue

            unit = scan_units_near(line_text)
            if not unit:
                continue  # sans unité détectée, trop risqué de conclure à une variable

            # Le libellé = texte de la ligne moins l'unité et les nombres isolés
            label_part = re.sub(r"(?<![A-Za-zÀ-ÿ])" + re.escape(unit) + r"(?![A-Za-zÀ-ÿ])", "", line_text)
            label_part = re.sub(r"\b\d+([.,]\d+)?\b", "", label_part).strip(" :-–\t")
            if len(label_part) < 2 or len(label_part) > 60:
                continue

            fields.append(
                ExtractedField(
                    key=slugify(label_part),
                    label=label_part,
                    unit=unit,
                    source="reconstruction_xy",
                    confidence="basse",
                    raw_text=line_text,
                    page_number=page["page_number"],
                )
            )

    if verbose:
        print(f"  {len(fields)} champ(s) reconstruit(s) via clustering x/y", file=sys.stderr)
    return fields


# ============================================================================
# COUCHE 4 - DÉDUPLICATION ET SCORING DE CONFIANCE
# ============================================================================

def deduplicate_fields(fields: list[ExtractedField]) -> list[ExtractedField]:
    """Fusionne les doublons (même clé technique) en conservant la version
    la plus fiable (priorité: table_detectee > reconstruction_xy)."""
    priority = {"table_detectee": 3, "regex": 2, "reconstruction_xy": 1}
    best: dict[str, ExtractedField] = {}
    for f in fields:
        existing = best.get(f.key)
        if existing is None or priority.get(f.source, 0) > priority.get(existing.source, 0):
            best[f.key] = f
    return list(best.values())


def refine_confidence(fields: list[ExtractedField]) -> None:
    """Ajuste la confiance finale selon des règles de cohérence croisée :
    un champ avec unité connue ET clé reconnue dans COMMON_VARIABLES_HINTS
    passe en confiance haute ; un champ sans unité redescend en confiance basse."""
    for f in fields:
        recognized = any(
            any(normalize(hint) in normalize(f.label) for hint in hints)
            for hints in COMMON_VARIABLES_HINTS.values()
        )
        if recognized and f.unit:
            f.confidence = "haute"
        elif not f.unit:
            f.confidence = "basse"



# ============================================================================
# EXTRACTION DETERMINISTE DES FORMULES
# ============================================================================

def extract_formulas(full_text: str, fields: list[ExtractedField]) -> list[ExtractedFormula]:
    """Extracts simple equations from PDF text; never invents a formula."""
    formulas: list[ExtractedFormula] = []
    seen: set[tuple[str, str]] = set()
    # Accept common equation bullets and reject prose containing an equals sign.
    pattern = re.compile(
        r"^\s*(?:[-?*]\s*)?(?P<lhs>[A-Za-z?-??-???????][^=]{0,80}?)\s*=\s*"
        r"(?P<rhs>[^;]{3,180})$"
    )
    for raw_line in full_text.splitlines():
        line = " ".join(raw_line.strip().split())
        match = pattern.match(line)
        if not match:
            continue
        lhs = match.group("lhs").strip(" -:()")
        rhs = match.group("rhs").strip(" .")
        if len(lhs) < 1 or len(rhs) < 3:
            continue
        if not re.search(r"[*/^??()]", rhs):
            continue
        # Normalize only unambiguous mathematical typography.
        formula = rhs.replace("?", "*").replace("?", "/").replace("?", "-")
        output_key = slugify(lhs)
        if output_key in {"champ", "norme", "version"}:
            continue
        key = (output_key, formula)
        if key in seen:
            continue
        seen.add(key)
        unit = scan_units_near(line)
        formulas.append(
            ExtractedFormula(
                output_key=output_key,
                label=lhs,
                formula=formula,
                unit=unit,
                confidence="moyenne",
                status="needs_review",
                raw_detected_formula=line,
            )
        )
    return formulas


# ============================================================================
# COUCHE 5 - CONSTRUCTION DU JSON DE SORTIE
# ============================================================================

def build_schema_draft(pdf_path: Path, result: ExtractionResult) -> dict[str, Any]:
    protocol_slug = slugify(result.norm_code or pdf_path.stem)
    inputs_schema = []
    for f in result.fields:
        inputs_schema.append(
            {
                "key": f.key,
                "label": f.label,
                "type": f.type,
                "unit": f.unit,
                "required": f.required,
                "symbol": f.symbol,
                "extraction": {
                    "source": f.source,
                    "confidence": f.confidence,
                },
            }
        )

    return {
        "protocol_id": f"{protocol_slug}_draft",
        "metadata": {
            "norme": result.norm_code,
            "norme_confidence": result.norm_code_confidence,
            "essai": result.title,
            "materiau_detecte": result.material_hint,
            "titre": result.title,
            "version": "0.1-draft",
            "created_at": datetime.now(timezone.utc).isoformat(),
            "source_pdf": pdf_path.name,
        },
        "inputs_schema": inputs_schema,
        "calculations": [
            {
                "output_key": f.output_key,
                "label": f.label,
                "unit": f.unit,
                "formula": f.formula,
                "raw_detected_formula": f.raw_detected_formula,
                "status": f.status,
                "confidence": f.confidence,
            }
            for f in result.formulas
        ],
        "validation_rules": {},
        "extraction_summary": {
            "total_champs_extraits": len(result.fields),
            "total_formules_extraites": len(result.formulas),
            "confiance_haute": sum(1 for f in result.fields if f.confidence == "haute"),
            "confiance_moyenne": sum(1 for f in result.fields if f.confidence == "moyenne"),
            "confiance_basse": sum(1 for f in result.fields if f.confidence == "basse"),
            "avertissements": result.warnings,
            "note": (
                "Ce fichier est un brouillon généré automatiquement (sans LLM, "
                "100% local). Les champs à confiance 'moyenne' ou 'basse' "
                "doivent être vérifiés par l'opérateur du laboratoire dans "
                "l'éditeur no-code avant validation du protocole."
            ),
        },
    }


# ============================================================================
# ORCHESTRATION
# ============================================================================

def run_extraction(pdf_path: Path, verbose: bool = False) -> dict[str, Any]:
    if verbose:
        print(f"[1/5] Extraction brute de {pdf_path.name}...", file=sys.stderr)
    raw = extract_raw(pdf_path, verbose=verbose)
    pages = raw["pages"]
    full_text = raw["full_text"]

    warnings = []
    if raw.get("ocr_failed_binary"):
        warnings.append(
            "Ce PDF semble être scanné et l'OCR local n'a pas pu s'exécuter. "
            "Pour activer l'OCR, veuillez installer Tesseract-OCR sur votre machine et la bibliothèque 'pytesseract'."
        )

    if not full_text.strip():
        result = ExtractionResult(
            warnings=warnings + ["Aucun texte extrait : le PDF est peut-être scanné (image) sans OCR."]
        )
        return build_schema_draft(pdf_path, result)

    if verbose:
        print("[2/5] Détection des patterns génériques (code, titre, matériau)...", file=sys.stderr)
    norm_code, norm_confidence = detect_norm_code(full_text)
    title = detect_title(full_text, norm_code)
    material_hint = detect_material_hint(full_text)
    find_section_spans(pages, verbose=verbose)  # utilisé pour futurs raffinements ciblés

    if verbose:
        print("[3/5] Extraction des variables via tables détectées...", file=sys.stderr)
    table_fields = extract_fields_from_tables(pages, verbose=verbose)
    pages_with_table_fields = {f.page_number for f in table_fields if f.page_number is not None}

    if verbose:
        print("[4/5] Reconstruction des tableaux sans bordures (pages restantes)...", file=sys.stderr)
    xy_fields = reconstruct_fields_from_words(pages, pages_with_table_fields=pages_with_table_fields, verbose=verbose)

    all_fields = deduplicate_fields(table_fields + xy_fields)
    refine_confidence(all_fields)
    formulas = extract_formulas(full_text, all_fields)

    if norm_confidence == "basse":
        warnings.append("Code de norme non détecté automatiquement : à saisir manuellement.")
    if not all_fields:
        warnings.append("Aucune variable n'a pu être extraite automatiquement : saisie manuelle requise.")

    if verbose:
        print(f"[5/5] Génération du JSON de pré-remplissage ({len(all_fields)} champ(s))...", file=sys.stderr)

    result = ExtractionResult(
        norm_code=norm_code,
        norm_code_confidence=norm_confidence,
        title=title,
        material_hint=material_hint,
        fields=all_fields,
        formulas=formulas,
        warnings=warnings,
    )
    return build_schema_draft(pdf_path, result)


def main():
    # Python hérite souvent de cp1252 sur Windows, qui ne sait pas afficher
    # le symbole de validation utilisé par le résumé CLI.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(
        description=(
            "Extrait automatiquement, sans LLM et sans modèle de mise en page fixe, "
            "les paramètres d'une norme d'essai mécanique (PDF) vers un JSON de "
            "pré-remplissage pour l'éditeur no-code PycnoLab."
        )
    )
    parser.add_argument("--input", "-i", required=True, help="Chemin du PDF de norme source")
    parser.add_argument("--output", "-o", required=True, help="Chemin du JSON de sortie (schema_draft.json)")
    parser.add_argument("--verbose", "-v", action="store_true", help="Affiche le détail de chaque couche d'extraction")
    args = parser.parse_args()

    pdf_path = Path(args.input)
    if not pdf_path.exists():
        print(f"Erreur: fichier introuvable: {pdf_path}", file=sys.stderr)
        sys.exit(1)

    schema = run_extraction(pdf_path, verbose=args.verbose)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(schema, f, ensure_ascii=False, indent=2)

    summary = schema["extraction_summary"]
    try:
        print(f"\n[OK] JSON généré : {output_path}")
    except UnicodeEncodeError:
        print(f"\n[OK] JSON genere : {output_path}")
    print(f"  Norme détectée      : {schema['metadata']['norme'] or '(non détectée)'}")
    print(f"  Champs extraits      : {summary['total_champs_extraits']}")
    print(
        f"  Confiance haute/moy./basse : "
        f"{summary['confiance_haute']} / {summary['confiance_moyenne']} / {summary['confiance_basse']}"
    )
    if summary["avertissements"]:
        print("  Avertissements :")
        for w in summary["avertissements"]:
            print(f"    - {w}")


if __name__ == "__main__":
    main()
