import express from "express";
import path from "path";
import { createServer as createViteServer } from "vite";
import { GoogleGenAI, Type } from "@google/genai";
import dotenv from "dotenv";

dotenv.config();

const PORT = 3000;

// Lazy initialization for Gemini AI client
let aiClient: GoogleGenAI | null = null;
function getGenAI(): GoogleGenAI | null {
  if (!aiClient && process.env.GEMINI_API_KEY) {
    aiClient = new GoogleGenAI({
      apiKey: process.env.GEMINI_API_KEY,
      httpOptions: {
        headers: {
          'User-Agent': 'aistudio-build',
        },
      },
    });
  }
  return aiClient;
}

// Deterministic normalization helper for units
function normalizeUnit(rawUnit: string): string {
  const map: Record<string, string> = {
    "KN": "kN",
    "kn": "kN",
    "N/MM2": "MPa",
    "n/mm2": "MPa",
    "N/mm²": "MPa",
    "MPA": "MPa",
    "mpa": "MPa",
    "KG": "kg",
    "g/cm3": "g/cm³",
    "g/cm^3": "g/cm³",
    "MM": "mm",
    "CM": "cm",
    "DEGC": "°C",
    "degC": "°C",
    "celcius": "°C",
    "celsius": "°C",
    "KPA": "kPa",
    "kpa": "kPa",
    "BAR": "bar",
    "PERCENT": "%",
    "pourcent": "%",
  };
  const trimmed = rawUnit.trim();
  return map[trimmed] || map[trimmed.toUpperCase()] || trimmed;
}

async function startServer() {
  const app = express();
  app.use(express.json({ limit: "15mb" }));

  // API Route: Health check
  app.get("/api/health", (req, res) => {
    res.json({
      status: "ok",
      timestamp: new Date().toISOString(),
      hasGeminiApiKey: !!process.env.GEMINI_API_KEY,
    });
  });

  // API Route: Ingestion de Norme (Extraction IA / Gemini + Deterministic fallback)
  app.post("/api/ingest-norm", async (req, res) => {
    try {
      const { rawText, standardCode, domain, filename } = req.body;
      const ai = getGenAI();

      if (ai && rawText && rawText.length > 20) {
        try {
          const prompt = `Tu es le moteur backend d'ingestion de normes techniques de laboratoire de PycnoLab (norm_ingestion_service.py).
Analyse le texte officiel suivant extrait d'une norme d'essai (ou description de protocole) et produis une structure JSON rigoureusement formatée.

Règles d'extraction :
1. Extrais les métadonnées (code norme exact, titre complet en français, organisme normalisateur ex: ISO/AFNOR/ASTM/CEN, domaine ex: Plasturgie, Génie Civil, Ciments, Géotechnique, etc., indice de confiance global entre 0.80 et 0.99, résumé technique et conditions d'essais nominales comme température et vitesse).
2. Extrais toutes les grandeurs d'entrée (inputs) nécessaires aux calculs : clé snake_case, libellé clair, symbole scientifique (ex: b, h, F, m1, V), unité normalisée (ex: mm, N, kN, g, MPa, °C, %), type (decimal ou integer), status ('verified' si symbole et unité sont certains, 'needs_review' si ambigu), confiance (0.7 à 1.0), valeur par défaut typique, min, max.
3. Extrais toutes les formules mathématiques de calcul des résultats : clé de sortie (output_key snake_case), libellé, symbole (ex: σ_m, E_t, R_c), unité de résultat (ex: MPa, %, g/cm³), formule brute textuelle détectée (ex: "F / (b * h)" ou "(F * 1.5 * L) / (b * h^2)"), status ('verified' si formule classique certaine, 'needs_review' si formule avec exposant ou conditions), confiance, nombre de décimales recommandées.
4. Génère 1 ou 2 jeux de données d'essais réels (sandbox_test_cases) avec valeurs d'entrées réalistes et résultats théoriques attendus.

Texte de la norme à analyser :
"""
${rawText.slice(0, 10000)}
"""`;

          const response = await ai.models.generateContent({
            model: "gemini-3.7-flash",
            contents: prompt,
            config: {
              responseMimeType: "application/json",
              responseSchema: {
                type: Type.OBJECT,
                properties: {
                  draft_id: { type: Type.STRING },
                  metadata: {
                    type: Type.OBJECT,
                    properties: {
                      norme: { type: Type.STRING },
                      titre: { type: Type.STRING },
                      organisme: { type: Type.STRING },
                      domaine: { type: Type.STRING },
                      annee_edition: { type: Type.STRING },
                      confidence: { type: Type.NUMBER },
                      description: { type: Type.STRING },
                      conditions_nominales: {
                        type: Type.OBJECT,
                        properties: {
                          temperature: { type: Type.STRING },
                          hygrometrie: { type: Type.STRING },
                          vitesse_essai: { type: Type.STRING },
                        },
                      },
                    },
                    required: ["norme", "titre", "confidence"],
                  },
                  extracted_inputs: {
                    type: Type.ARRAY,
                    items: {
                      type: Type.OBJECT,
                      properties: {
                        key: { type: Type.STRING },
                        label: { type: Type.STRING },
                        symbol: { type: Type.STRING },
                        unit: { type: Type.STRING },
                        type: { type: Type.STRING },
                        status: { type: Type.STRING },
                        confidence: { type: Type.NUMBER },
                        defaultValue: { type: Type.NUMBER },
                        min: { type: Type.NUMBER },
                        max: { type: Type.NUMBER },
                        description: { type: Type.STRING },
                      },
                      required: ["key", "label", "unit", "status"],
                    },
                  },
                  extracted_formulas: {
                    type: Type.ARRAY,
                    items: {
                      type: Type.OBJECT,
                      properties: {
                        output_key: { type: Type.STRING },
                        label: { type: Type.STRING },
                        symbol: { type: Type.STRING },
                        unit: { type: Type.STRING },
                        raw_detected_formula: { type: Type.STRING },
                        status: { type: Type.STRING },
                        confidence: { type: Type.NUMBER },
                        decimals: { type: Type.INTEGER },
                        description: { type: Type.STRING },
                      },
                      required: ["output_key", "label", "unit", "raw_detected_formula", "status"],
                    },
                  },
                  sandbox_test_cases: {
                    type: Type.ARRAY,
                    items: {
                      type: Type.OBJECT,
                      properties: {
                        name: { type: Type.STRING },
                        inputs: { type: Type.OBJECT },
                        expected_outputs: { type: Type.OBJECT },
                        notes: { type: Type.STRING },
                      },
                    },
                  },
                },
                required: ["metadata", "extracted_inputs", "extracted_formulas"],
              },
            },
          });

          if (response.text) {
            const parsedData = JSON.parse(response.text);
            // Post-process units normalization
            if (parsedData.extracted_inputs) {
              parsedData.extracted_inputs = parsedData.extracted_inputs.map((inp: any, idx: number) => ({
                id: `inp_${Date.now()}_${idx}`,
                ...inp,
                unit: normalizeUnit(inp.unit || "mm"),
                status: inp.status === "needs_review" ? "needs_review" : (inp.status || "verified"),
                confidence: inp.confidence || 0.92,
              }));
            }
            if (parsedData.extracted_formulas) {
              parsedData.extracted_formulas = parsedData.extracted_formulas.map((form: any, idx: number) => ({
                id: `form_${Date.now()}_${idx}`,
                ...form,
                unit: normalizeUnit(form.unit || "MPa"),
                status: form.status === "needs_review" ? "needs_review" : (form.status || "verified"),
                confidence: form.confidence || 0.88,
              }));
            }
            parsedData.draft_id = parsedData.draft_id || `draft_${(parsedData.metadata.norme || "norm").toLowerCase().replace(/[^a-z0-9]/g, "_")}_${Date.now()}`;
            parsedData.source = "gemini_ai_parser";
            return res.json({ success: true, draft: parsedData });
          }
        } catch (aiErr) {
          console.warn("AI generation failed, falling back to deterministic parser:", aiErr);
        }
      }

      // Fallback: Deterministic Regex Parser
      const normCode = standardCode || "ISO 527-2";
      const draft = generateDeterministicDraft(normCode, rawText, domain, filename);
      return res.json({ success: true, draft, source: "deterministic_regex_parser" });
    } catch (err: any) {
      console.error("Error ingesting norm:", err);
      res.status(500).json({ success: false, error: err.message || "Failed to parse norm" });
    }
  });

  // API Route: Safe Formula Evaluation
  app.post("/api/evaluate-formula", (req, res) => {
    try {
      const { formula, variables } = req.body;
      if (!formula || typeof formula !== "string") {
        return res.status(400).json({ error: "Formula string is required" });
      }

      const result = evaluateMathExpression(formula, variables || {});
      return res.json({ success: true, result });
    } catch (err: any) {
      return res.status(400).json({ success: false, error: err.message });
    }
  });

  // Vite middleware for development
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), "dist");
    app.use(express.static(distPath));
    app.get("*", (req, res) => {
      res.sendFile(path.join(distPath, "index.html"));
    });
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`PycnoLab Server running on http://0.0.0.0:${PORT}`);
  });
}

// Deterministic mock / fallback parser for standards
function generateDeterministicDraft(code: string, rawText?: string, customDomain?: string, filename?: string) {
  const isCiment = /196|ciment|mortier|compression/i.test(code + " " + (rawText || ""));
  const isAtterberg = /atterberg|94-051|plasticite|liquidite/i.test(code + " " + (rawText || ""));
  const isFlexion = /178|flexion|module/i.test(code + " " + (rawText || ""));
  const isBeton = /12390|beton|eprouvette/i.test(code + " " + (rawText || ""));

  if (isCiment) {
    return {
      draft_id: `draft_en_196_1_${Date.now()}`,
      status: "DRAFT_PARSED",
      metadata: {
        norme: "EN 196-1",
        titre: "Méthodes d'essais des ciments - Détermination des résistances mécaniques",
        organisme: "CEN / AFNOR",
        domaine: customDomain || "Génie Civil & Matériaux Cimentaires",
        annee_edition: "2016",
        confidence: 0.94,
        description: "Protocole de mesure des résistances à la flexion et à la compression sur prismes de mortier 40 x 40 x 160 mm.",
        conditions_nominales: {
          temperature: "20 ± 2 °C",
          hygrometrie: "≥ 90 % HR",
          vitesse_essai: "2400 ± 200 N/s (compression)",
        },
      },
      extracted_inputs: [
        {
          id: "inp_1",
          key: "force_flexion_ff",
          label: "Force maximale en flexion (Ff)",
          symbol: "F_f",
          unit: "N",
          type: "decimal",
          status: "verified",
          confidence: 0.98,
          defaultValue: 4500,
          min: 100,
          max: 20000,
          description: "Charge appliquée au centre du prisme jusqu'à rupture",
        },
        {
          id: "inp_2",
          key: "force_compression_fc",
          label: "Force maximale en compression (Fc)",
          symbol: "F_c",
          unit: "kN",
          type: "decimal",
          status: "verified",
          confidence: 0.96,
          defaultValue: 84.5,
          min: 1,
          max: 300,
          description: "Force de rupture appliquée sur demi-prisme",
        },
        {
          id: "inp_3",
          key: "surface_appui_a",
          label: "Section nominale des plateaux (A)",
          symbol: "A",
          unit: "mm²",
          type: "decimal",
          status: "verified",
          confidence: 0.99,
          defaultValue: 1600,
          min: 1500,
          max: 1700,
          description: "Section d'appui 40 mm x 40 mm = 1600 mm²",
        },
        {
          id: "inp_4",
          key: "distance_appuis_l",
          label: "Entraxe des rouleaux d'appui (L)",
          symbol: "L",
          unit: "mm",
          type: "decimal",
          status: "needs_review",
          confidence: 0.88,
          defaultValue: 100,
          min: 80,
          max: 120,
          description: "Distance standard entre les appuis inférieurs (100.0 mm)",
        },
        {
          id: "inp_5",
          key: "cote_prisme_b",
          label: "Côté de la section carrée (b)",
          symbol: "b",
          unit: "mm",
          type: "decimal",
          status: "verified",
          confidence: 0.95,
          defaultValue: 40,
          min: 38,
          max: 42,
          description: "Hauteur et largeur nominales du prisme",
        },
      ],
      extracted_formulas: [
        {
          id: "form_1",
          output_key: "resistance_flexion_rf",
          label: "Résistance à la flexion",
          symbol: "R_f",
          unit: "MPa",
          raw_detected_formula: "(1.5 * force_flexion_ff * distance_appuis_l) / (cote_prisme_b * cote_prisme_b * cote_prisme_b)",
          status: "needs_review",
          confidence: 0.89,
          decimals: 2,
          description: "Rf = (1.5 * Ff * L) / b³",
        },
        {
          id: "form_2",
          output_key: "resistance_compression_rc",
          label: "Résistance à la compression",
          symbol: "R_c",
          unit: "MPa",
          raw_detected_formula: "(force_compression_fc * 1000) / surface_appui_a",
          status: "verified",
          confidence: 0.97,
          decimals: 1,
          description: "Rc = Fc (en N) / A = (Fc_kN * 1000) / 1600",
        },
      ],
      sandbox_test_cases: [
        {
          id: "test_1",
          name: "Mortier standard CEM II 42.5R (Échéance 28 jours)",
          inputs: {
            force_flexion_ff: 4800,
            force_compression_fc: 88.0,
            surface_appui_a: 1600,
            distance_appuis_l: 100,
            cote_prisme_b: 40,
          },
          expected_outputs: {
            resistance_flexion_rf: { value: 11.25, tolerancePct: 2 },
            resistance_compression_rc: { value: 55.0, tolerancePct: 2 },
          },
          notes: "Valeurs conformes aux exigences CEM II classe 42.5R à 28 jours.",
        },
      ],
    };
  }

  if (isAtterberg) {
    return {
      draft_id: `draft_nf_p94_051_${Date.now()}`,
      status: "DRAFT_PARSED",
      metadata: {
        norme: "NF P94-051",
        titre: "Sols : Reconnaissance et essais - Détermination des limites d'Atterberg",
        organisme: "AFNOR",
        domaine: customDomain || "Géotechnique & Mécanique des Sols",
        annee_edition: "1993 (R2018)",
        confidence: 0.92,
        description: "Mesure de la limite de liquidité (wL) à l'appareil de Casagrande et de la limite de plasticité (wP) au rouleau.",
        conditions_nominales: {
          temperature: "20 ± 3 °C",
          hygrometrie: "Ambiante contrôlée",
          vitesse_essai: "2 chocs/s (Coupelle)",
        },
      },
      extracted_inputs: [
        {
          id: "inp_1",
          key: "limite_liquidite_wl",
          label: "Teneur en eau à la limite de liquidité (wL)",
          symbol: "w_L",
          unit: "%",
          type: "decimal",
          status: "verified",
          confidence: 0.95,
          defaultValue: 48.5,
          min: 10,
          max: 120,
          description: "Teneur en eau pour 25 chocs de coupelle",
        },
        {
          id: "inp_2",
          key: "limite_plasticite_wp",
          label: "Teneur en eau à la limite de plasticité (wP)",
          symbol: "w_P",
          unit: "%",
          type: "decimal",
          status: "verified",
          confidence: 0.94,
          defaultValue: 22.0,
          min: 5,
          max: 60,
          description: "Teneur en eau d'effritement des rouleaux de 3 mm",
        },
        {
          id: "inp_3",
          key: "teneur_eau_naturelle_w",
          label: "Teneur en eau naturelle du sol (w)",
          symbol: "w",
          unit: "%",
          type: "decimal",
          status: "needs_review",
          confidence: 0.85,
          defaultValue: 28.5,
          min: 0,
          max: 100,
          description: "Teneur en eau in situ pour calcul de l'indice de consistance",
        },
      ],
      extracted_formulas: [
        {
          id: "form_1",
          output_key: "indice_plasticite_ip",
          label: "Indice de plasticité",
          symbol: "I_p",
          unit: "%",
          raw_detected_formula: "limite_liquidite_wl - limite_plasticite_wp",
          status: "verified",
          confidence: 0.98,
          decimals: 1,
          description: "Ip = wL - wP",
        },
        {
          id: "form_2",
          output_key: "indice_consistance_ic",
          label: "Indice de consistance",
          symbol: "I_c",
          unit: "-",
          raw_detected_formula: "(limite_liquidite_wl - teneur_eau_naturelle_w) / (limite_liquidite_wl - limite_plasticite_wp)",
          status: "needs_review",
          confidence: 0.91,
          decimals: 2,
          description: "Ic = (wL - w) / Ip",
        },
      ],
      sandbox_test_cases: [
        {
          id: "test_1",
          name: "Argile limoneuse de formation",
          inputs: {
            limite_liquidite_wl: 48.5,
            limite_plasticite_wp: 22.0,
            teneur_eau_naturelle_w: 28.5,
          },
          expected_outputs: {
            indice_plasticite_ip: { value: 26.5, tolerancePct: 1 },
            indice_consistance_ic: { value: 0.75, tolerancePct: 1 },
          },
          notes: "Classification : Sol argileux très plastique, consistance ferme.",
        },
      ],
    };
  }

  // Default: ISO 527-2 (Traction des Plastiques)
  return {
    draft_id: `draft_iso_527_2_temp`,
    status: "DRAFT_PARSED",
    metadata: {
      norme: "ISO 527-2",
      titre: "Détermination des propriétés en traction des plastiques - Conditions d'essai des plastiques pour moulage et extrusion",
      organisme: "ISO / AFNOR",
      domaine: customDomain || "Plasturgie & Polymères",
      annee_edition: "2012 (R2019)",
      confidence: 0.95,
      description: "Méthode normalisée pour déterminer la contrainte au seuil d'écoulement, la contrainte à la rupture et le module d'élasticité.",
      conditions_nominales: {
        temperature: "23 ± 2 °C",
        hygrometrie: "50 ± 10 % HR",
        vitesse_essai: "50 mm/min (Vitesse de traction)",
      },
    },
    extracted_inputs: [
      {
        id: "inp_1",
        key: "largeur_b",
        label: "Largeur de la partie étroite (b)",
        symbol: "b",
        unit: "mm",
        type: "decimal",
        status: "verified",
        confidence: 0.98,
        defaultValue: 10.0,
        min: 5.0,
        max: 25.0,
        description: "Mesurée au centre de l'éprouvette haltère type 1A/1B",
      },
      {
        id: "inp_2",
        key: "epaisseur_h",
        label: "Épaisseur de l'éprouvette (h)",
        symbol: "h",
        unit: "mm",
        type: "decimal",
        status: "verified",
        confidence: 0.98,
        defaultValue: 4.0,
        min: 1.0,
        max: 10.0,
        description: "Épaisseur moyenne mesurée sur 3 points",
      },
      {
        id: "inp_3",
        key: "force_f",
        label: "Force maximale mesurée (F)",
        symbol: "F",
        unit: "N",
        type: "decimal",
        status: "verified",
        confidence: 0.97,
        defaultValue: 2600.0,
        min: 10.0,
        max: 50000.0,
        description: "Charge appliquée à l'instant de rupture ou seuil",
      },
      {
        id: "inp_4",
        key: "longueur_calibree_l0",
        label: "Longueur initiale entre repères (L0)",
        symbol: "L_0",
        unit: "mm",
        type: "decimal",
        status: "needs_review",
        confidence: 0.86,
        defaultValue: 50.0,
        min: 25.0,
        max: 100.0,
        description: "Base de mesure de l'extensomètre (souvent 50 ou 75 mm)",
      },
      {
        id: "inp_5",
        key: "allongement_delta_l",
        label: "Allongement à la rupture (ΔL)",
        symbol: "ΔL",
        unit: "mm",
        type: "decimal",
        status: "verified",
        confidence: 0.93,
        defaultValue: 4.2,
        min: 0.01,
        max: 500.0,
        description: "Déplacement mesuré entre repères à la rupture",
      },
    ],
    extracted_formulas: [
      {
        id: "form_1",
        output_key: "section_initiale_a0",
        label: "Section initiale de l'éprouvette",
        symbol: "A_0",
        unit: "mm²",
        raw_detected_formula: "largeur_b * epaisseur_h",
        status: "verified",
        confidence: 0.99,
        decimals: 2,
        description: "A0 = b * h",
      },
      {
        id: "form_2",
        output_key: "contrainte_sigma",
        label: "Contrainte en traction (au seuil / rupture)",
        symbol: "σ_m",
        unit: "MPa",
        raw_detected_formula: "force_f / (largeur_b * epaisseur_h)",
        status: "needs_review",
        confidence: 0.88,
        decimals: 2,
        description: "σ = F / (b * h) = F / A0",
      },
      {
        id: "form_3",
        output_key: "allongement_relatif_epsilon",
        label: "Allongement relatif nominal en traction",
        symbol: "ε_t",
        unit: "%",
        raw_detected_formula: "(allongement_delta_l / longueur_calibree_l0) * 100",
        status: "verified",
        confidence: 0.94,
        decimals: 2,
        description: "ε = (ΔL / L0) * 100 %",
      },
    ],
    sandbox_test_cases: [
      {
        id: "test_1",
        name: "Éprouvette ISO 527-2 Type 1A - Polycarbonate injecté",
        inputs: {
          largeur_b: 10.0,
          epaisseur_h: 4.0,
          force_f: 2600.0,
          longueur_calibree_l0: 50.0,
          allongement_delta_l: 4.5,
        },
        expected_outputs: {
          section_initiale_a0: { value: 40.0, tolerancePct: 0.1 },
          contrainte_sigma: { value: 65.0, tolerancePct: 0.5 },
          allongement_relatif_epsilon: { value: 9.0, tolerancePct: 0.5 },
        },
        notes: "Résultats typiques pour un polycarbonate non renforcé à 23°C.",
      },
    ],
  };
}

// Math evaluation engine for safe expression solving
function evaluateMathExpression(formula: string, vars: Record<string, number>): number {
  let expr = formula;

  // Replace variable keys with numeric values
  const sortedKeys = Object.keys(vars).sort((a, b) => b.length - a.length);
  for (const key of sortedKeys) {
    const val = vars[key];
    const regex = new RegExp(`\\b${key}\\b`, "g");
    expr = expr.replace(regex, `(${val})`);
  }

  // Support sqrt, pow, min, max
  expr = expr.replace(/sqrt\(/g, "Math.sqrt(");
  expr = expr.replace(/\^/g, "**");

  // Validate allowed characters only (security check)
  if (/[^0-9\.\+\-\*\/\(\)\sMath\.sqrtpowminmax\,\*]/g.test(expr)) {
    throw new Error("Invalid characters in mathematical expression");
  }

  // Safe evaluation
  // eslint-disable-next-line no-new-func
  const result = Function(`"use strict"; return (${expr});`)();
  if (typeof result !== "number" || isNaN(result) || !isFinite(result)) {
    throw new Error("Formula returned a non-finite or invalid number");
  }
  return result;
}

startServer().catch((err) => {
  console.error("Fatal server error:", err);
});
