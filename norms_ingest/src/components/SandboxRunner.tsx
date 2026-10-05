import React, { useState, useEffect } from 'react';
import { 
  NormDraft, 
  SandboxTestCase, 
  FormulaDefinition, 
  InputVariable 
} from '../types';
import { evaluateFormulaClient } from '../utils/formulaUtils';
import { 
  Play, 
  CheckCircle2, 
  AlertCircle, 
  Plus, 
  Sparkles, 
  TrendingUp, 
  FlaskConical, 
  Sliders,
  RotateCcw,
  Check
} from 'lucide-react';

interface SandboxRunnerProps {
  draft: NormDraft;
  onUpdateDraft: (updated: NormDraft) => void;
}

export const SandboxRunner: React.FC<SandboxRunnerProps> = ({ draft, onUpdateDraft }) => {
  const [selectedCaseId, setSelectedCaseId] = useState<string>(
    draft.sandbox_test_cases[0]?.id || 'custom'
  );
  const [currentInputs, setCurrentInputs] = useState<Record<string, number>>({});
  const [calculatedOutputs, setCalculatedOutputs] = useState<Record<string, number>>({});
  const [calcErrors, setCalcErrors] = useState<Record<string, string>>({});
  const [newCaseName, setNewCaseName] = useState('');
  const [showAddCaseModal, setShowAddCaseModal] = useState(false);

  // Initialize input values from chosen test case or default values
  useEffect(() => {
    const testCase = draft.sandbox_test_cases.find((c) => c.id === selectedCaseId);
    const initialVals: Record<string, number> = {};

    draft.extracted_inputs.forEach((inp) => {
      if (testCase && testCase.inputs[inp.key] !== undefined) {
        initialVals[inp.key] = testCase.inputs[inp.key];
      } else if (inp.defaultValue !== undefined) {
        initialVals[inp.key] = inp.defaultValue;
      } else {
        initialVals[inp.key] = 10;
      }
    });

    setCurrentInputs(initialVals);
  }, [selectedCaseId, draft.extracted_inputs, draft.sandbox_test_cases]);

  // Recalculate outputs whenever inputs or formulas change
  useEffect(() => {
    const outputs: Record<string, number> = {};
    const errors: Record<string, string> = {};

    // Clone variable state to allow chaining formula outputs
    const scope: Record<string, number> = { ...currentInputs };

    draft.extracted_formulas.forEach((form) => {
      try {
        const val = evaluateFormulaClient(form.raw_detected_formula, scope);
        outputs[form.output_key] = val;
        scope[form.output_key] = val; // Available to downstream formulas
      } catch (err: any) {
        errors[form.output_key] = err.message || 'Erreur de calcul';
      }
    });

    setCalculatedOutputs(outputs);
    setCalcErrors(errors);
  }, [currentInputs, draft.extracted_formulas]);

  const handleInputChange = (key: string, valStr: string) => {
    const num = parseFloat(valStr);
    setCurrentInputs((prev) => ({
      ...prev,
      [key]: isNaN(num) ? 0 : num,
    }));
  };

  const handleResetInputs = () => {
    const testCase = draft.sandbox_test_cases.find((c) => c.id === selectedCaseId);
    const initialVals: Record<string, number> = {};
    draft.extracted_inputs.forEach((inp) => {
      if (testCase && testCase.inputs[inp.key] !== undefined) {
        initialVals[inp.key] = testCase.inputs[inp.key];
      } else {
        initialVals[inp.key] = inp.defaultValue || 10;
      }
    });
    setCurrentInputs(initialVals);
  };

  const handleSaveAsTestCase = () => {
    if (!newCaseName.trim()) return;
    const expectedOuts: Record<string, { value: number; tolerancePct: number }> = {};
    Object.keys(calculatedOutputs).forEach((key) => {
      expectedOuts[key] = {
        value: Number(calculatedOutputs[key].toFixed(2)),
        tolerancePct: 1.0,
      };
    });

    const newCase: SandboxTestCase = {
      id: `case_${Date.now()}`,
      name: newCaseName.trim(),
      inputs: { ...currentInputs },
      expected_outputs: expectedOuts,
      notes: `Étalon enregistré par l'opérateur le ${new Date().toLocaleDateString('fr-FR')}`,
    };

    onUpdateDraft({
      ...draft,
      sandbox_test_cases: [...draft.sandbox_test_cases, newCase],
    });

    setSelectedCaseId(newCase.id);
    setNewCaseName('');
    setShowAddCaseModal(false);
  };

  const currentCase = draft.sandbox_test_cases.find((c) => c.id === selectedCaseId);

  // Generate simulated Stress-Strain or Load curve points for visualization
  const isTensile = /sigma|traction|527|d638/i.test(draft.metadata.norme);
  const maxStress = calculatedOutputs['contrainte_sigma'] || calculatedOutputs['resistance_flexion_rf'] || calculatedOutputs['resistance_compression_rc'] || 65;
  const maxStrain = calculatedOutputs['allongement_relatif_epsilon'] || 10;

  return (
    <div className="space-y-6">
      {/* Sandbox Header Bar */}
      <div className="bg-slate-900 p-5 rounded-2xl border border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center space-x-2">
            <span className="px-2 py-0.5 text-xs font-bold rounded-md bg-indigo-500/20 text-indigo-300 border border-indigo-500/30">
              Sandbox d Essai Interactive
            </span>
            <span className="text-xs text-slate-400">
              Injection de données réelles & vérification instantanée des résultats
            </span>
          </div>
          <h3 className="text-base font-bold text-white mt-1">
            Contrôle Qualité & Comparaison Théorique ({draft.metadata.norme})
          </h3>
        </div>

        {/* Test Case Selector */}
        <div className="flex items-center space-x-2">
          <select
            value={selectedCaseId}
            onChange={(e) => setSelectedCaseId(e.target.value)}
            className="bg-slate-950 border border-slate-700 text-white text-xs rounded-xl px-3 py-2 focus:outline-none focus:border-blue-500 font-medium"
          >
            {draft.sandbox_test_cases.map((c) => (
              <option key={c.id} value={c.id}>
                📦 {c.name}
              </option>
            ))}
            <option value="custom">✏️ Jeu de données libre (Personnalisé)</option>
          </select>

          <button
            onClick={() => setShowAddCaseModal(true)}
            className="px-3 py-2 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition flex items-center space-x-1"
            title="Enregistrer les valeurs actuelles comme cas de test permanent"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Sauvegarder</span>
          </button>
        </div>
      </div>

      {/* Main Sandbox Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Input Variables Injection */}
        <div className="lg:col-span-5 bg-slate-900/90 p-5 rounded-2xl border border-slate-800 space-y-4">
          <div className="flex items-center justify-between pb-3 border-b border-slate-800">
            <h4 className="text-xs font-bold uppercase tracking-wider text-slate-300 flex items-center space-x-2">
              <Sliders className="w-4 h-4 text-blue-400" />
              <span>Grandeurs d Entrée Injectées</span>
            </h4>
            <button
              onClick={handleResetInputs}
              className="text-[11px] text-slate-400 hover:text-white transition flex items-center space-x-1"
            >
              <RotateCcw className="w-3 h-3" />
              <span>Réinitialiser</span>
            </button>
          </div>

          <div className="space-y-3 max-h-[420px] overflow-y-auto pr-1">
            {draft.extracted_inputs.map((inp) => (
              <div
                key={inp.id}
                className="bg-slate-950 p-3 rounded-xl border border-slate-800/80 hover:border-slate-700 transition"
              >
                <div className="flex items-center justify-between mb-1.5">
                  <label className="text-xs font-medium text-slate-200 flex items-center space-x-1.5">
                    <span className="font-bold text-white">{inp.symbol || inp.key}</span>
                    <span className="text-slate-400 text-[11px]">({inp.label})</span>
                  </label>
                  <span className="text-[11px] font-mono text-cyan-300 font-bold bg-cyan-950/60 px-2 py-0.5 rounded border border-cyan-800/40">
                    {inp.unit}
                  </span>
                </div>

                <div className="flex items-center space-x-3">
                  <input
                    type="number"
                    step="any"
                    value={currentInputs[inp.key] !== undefined ? currentInputs[inp.key] : ''}
                    onChange={(e) => handleInputChange(inp.key, e.target.value)}
                    className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-sm font-mono text-white focus:outline-none focus:border-blue-500"
                  />
                  {inp.min !== undefined && inp.max !== undefined && (
                    <span className="text-[10px] text-slate-500 whitespace-nowrap">
                      [{inp.min} - {inp.max}]
                    </span>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Right Column: Instant Calculated Outputs & Curve Preview */}
        <div className="lg:col-span-7 space-y-6">
          {/* Calculated Output Cards */}
          <div className="bg-slate-900/90 p-5 rounded-2xl border border-slate-800 space-y-4">
            <h4 className="text-xs font-bold uppercase tracking-wider text-slate-300 flex items-center space-x-2 pb-3 border-b border-slate-800">
              <FlaskConical className="w-4 h-4 text-emerald-400" />
              <span>Résultats Calculés Instantanés & Validation des Tolérances</span>
            </h4>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3.5">
              {draft.extracted_formulas.map((form) => {
                const val = calculatedOutputs[form.output_key];
                const error = calcErrors[form.output_key];
                const expected = currentCase?.expected_outputs?.[form.output_key];

                let isConform = true;
                let deltaPct = 0;
                if (expected && val !== undefined && !error) {
                  deltaPct = Math.abs(((val - expected.value) / expected.value) * 100);
                  isConform = deltaPct <= (expected.tolerancePct || 1.0);
                }

                return (
                  <div
                    key={form.id}
                    className={`p-4 rounded-xl border transition-all ${
                      error
                        ? 'bg-rose-950/20 border-rose-500/40'
                        : isConform
                        ? 'bg-slate-950 border-slate-800'
                        : 'bg-amber-950/20 border-amber-500/40'
                    }`}
                  >
                    <div className="flex items-center justify-between text-xs mb-1">
                      <span className="font-semibold text-slate-300">
                        {form.label} ({form.symbol || form.output_key})
                      </span>
                      <span className="text-[11px] font-bold text-slate-400 font-mono">
                        {form.unit}
                      </span>
                    </div>

                    {error ? (
                      <div className="text-xs text-rose-400 font-medium mt-2 flex items-center space-x-1">
                        <AlertCircle className="w-4 h-4 flex-shrink-0" />
                        <span>{error}</span>
                      </div>
                    ) : (
                      <div className="mt-1">
                        <div className="flex items-baseline space-x-2">
                          <span className="text-2xl font-bold font-mono text-white">
                            {val !== undefined ? val.toFixed(form.decimals ?? 2) : '—'}
                          </span>
                          <span className="text-xs text-slate-400 font-semibold">{form.unit}</span>
                        </div>

                        {/* Expected Standard Comparison */}
                        {expected && (
                          <div className="mt-2.5 pt-2 border-t border-slate-800/80 flex items-center justify-between text-[11px]">
                            <span className="text-slate-400">
                              Attendu : <strong className="text-slate-200">{expected.value} {form.unit}</strong>
                            </span>
                            {isConform ? (
                              <span className="inline-flex items-center space-x-1 text-emerald-400 font-semibold">
                                <CheckCircle2 className="w-3.5 h-3.5" />
                                <span>Conforme (Δ {deltaPct.toFixed(2)}%)</span>
                              </span>
                            ) : (
                              <span className="inline-flex items-center space-x-1 text-amber-400 font-semibold">
                                <AlertCircle className="w-3.5 h-3.5" />
                                <span>Écart &gt; Tolérance ({deltaPct.toFixed(1)}%)</span>
                              </span>
                            )}
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>

          {/* Interactive Mechanical Behavior Curve Preview */}
          <div className="bg-slate-900/90 p-5 rounded-2xl border border-slate-800">
            <div className="flex items-center justify-between mb-3">
              <h4 className="text-xs font-bold uppercase tracking-wider text-slate-300 flex items-center space-x-2">
                <TrendingUp className="w-4 h-4 text-cyan-400" />
                <span>Simulation Graphique de Comportement ({draft.metadata.domaine})</span>
              </h4>
              <span className="text-[11px] text-slate-400 font-mono">
                Points calculés selon l équation étalon
              </span>
            </div>

            <div className="bg-slate-950 p-4 rounded-xl border border-slate-800 flex flex-col items-center">
              {/* SVG Curve Plot */}
              <div className="w-full h-44 relative">
                <svg className="w-full h-full" viewBox="0 0 400 160">
                  {/* Grid lines */}
                  <line x1="40" y1="20" x2="380" y2="20" stroke="#334155" strokeDasharray="3,3" />
                  <line x1="40" y1="70" x2="380" y2="70" stroke="#334155" strokeDasharray="3,3" />
                  <line x1="40" y1="120" x2="380" y2="120" stroke="#334155" strokeDasharray="3,3" />
                  <line x1="120" y1="20" x2="120" y2="140" stroke="#334155" strokeDasharray="3,3" />
                  <line x1="200" y1="20" x2="200" y2="140" stroke="#334155" strokeDasharray="3,3" />
                  <line x1="280" y1="20" x2="280" y2="140" stroke="#334155" strokeDasharray="3,3" />

                  {/* Axes */}
                  <line x1="40" y1="140" x2="380" y2="140" stroke="#94a3b8" strokeWidth="1.5" />
                  <line x1="40" y1="20" x2="40" y2="140" stroke="#94a3b8" strokeWidth="1.5" />

                  {/* Curve path */}
                  <path
                    d="M 40 140 Q 140 30, 260 40 T 360 80"
                    fill="none"
                    stroke="#38bdf8"
                    strokeWidth="3"
                  />

                  {/* Yield point marker */}
                  <circle cx="260" cy="40" r="5" fill="#f59e0b" />
                  <text x="265" y="35" fill="#f59e0b" fontSize="10" fontWeight="bold">
                    Seuil σ_m ({maxStress.toFixed(1)} MPa)
                  </text>

                  {/* Rupture point marker */}
                  <circle cx="360" cy="80" r="5" fill="#ef4444" />
                  <text x="320" y="100" fill="#ef4444" fontSize="10">
                    Rupture (ε = {maxStrain.toFixed(1)}%)
                  </text>

                  {/* Labels */}
                  <text x="10" y="80" fill="#94a3b8" fontSize="10" transform="rotate(-90 10 80)">
                    Contrainte σ (MPa)
                  </text>
                  <text x="180" y="155" fill="#94a3b8" fontSize="10">
                    Déformation / Allongement ε (%)
                  </text>
                </svg>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Modal: Save As Test Case */}
      {showAddCaseModal && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl max-w-md w-full p-6 space-y-4 shadow-2xl">
            <h4 className="text-base font-bold text-white flex items-center space-x-2">
              <Sparkles className="w-5 h-5 text-indigo-400" />
              <span>Enregistrer comme Étalon de Test</span>
            </h4>
            <p className="text-xs text-slate-400 leading-relaxed">
              Ce jeu de données sera associé de façon permanente au protocole pour valider les futurs essais.
            </p>

            <div>
              <label className="text-xs font-semibold text-slate-300 block mb-1">
                Nom de l éprouvette / de l échantillon :
              </label>
              <input
                type="text"
                value={newCaseName}
                onChange={(e) => setNewCaseName(e.target.value)}
                placeholder="Ex: Éprouvette PC 1A Lot 2026-B"
                className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2 text-sm text-white focus:outline-none focus:border-blue-500"
              />
            </div>

            <div className="flex items-center justify-end space-x-3 pt-2">
              <button
                onClick={() => setShowAddCaseModal(false)}
                className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white transition"
              >
                Annuler
              </button>
              <button
                onClick={handleSaveAsTestCase}
                disabled={!newCaseName.trim()}
                className="px-4 py-2 rounded-xl text-xs font-semibold bg-blue-600 hover:bg-blue-500 text-white disabled:opacity-50 transition flex items-center space-x-1.5"
              >
                <Check className="w-3.5 h-3.5" />
                <span>Confirmer l enregistrement</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
