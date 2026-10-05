import React, { useState } from 'react';
import { 
  NormDraft, 
  InputVariable, 
  FormulaDefinition, 
  VerificationStatus,
  VariableType
} from '../types';
import { normalizeUnit } from '../utils/formulaUtils';
import { PillFormulaBuilder } from './PillFormulaBuilder';
import { SandboxRunner } from './SandboxRunner';
import confetti from 'canvas-confetti';
import { 
  Check, 
  AlertTriangle, 
  Plus, 
  Trash2, 
  ArrowLeft, 
  ArrowRight, 
  Save, 
  FileText, 
  Sliders, 
  Calculator, 
  FlaskConical, 
  CheckCircle2, 
  Braces, 
  Sparkles, 
  Eye, 
  Layers, 
  RefreshCw,
  Info,
  ShieldCheck
} from 'lucide-react';

interface EditeurProtocoleScreenProps {
  draft: NormDraft;
  onUpdateDraft: (updated: NormDraft) => void;
  onDeployProtocol: (deployed: NormDraft) => void;
  onBackToDashboard: () => void;
  onOpenJsonInspector: () => void;
}

export const EditeurProtocoleScreen: React.FC<EditeurProtocoleScreenProps> = ({
  draft,
  onUpdateDraft,
  onDeployProtocol,
  onBackToDashboard,
  onOpenJsonInspector,
}) => {
  const [currentStep, setCurrentStep] = useState<1 | 2 | 3 | 4>(1);
  const [editingInputId, setEditingInputId] = useState<string | null>(null);
  const [showAddInputModal, setShowAddInputModal] = useState(false);
  const [showAddFormulaModal, setShowAddFormulaModal] = useState(false);

  // New Input Form state
  const [newInput, setNewInput] = useState<Partial<InputVariable>>({
    key: '',
    label: '',
    symbol: '',
    unit: 'mm',
    type: 'decimal',
    defaultValue: 10,
    min: 0,
    max: 1000,
    status: 'manual_addition',
    confidence: 1.0,
  });

  // New Formula Form state
  const [newFormula, setNewFormula] = useState<Partial<FormulaDefinition>>({
    output_key: '',
    label: '',
    symbol: '',
    unit: 'MPa',
    raw_detected_formula: '',
    decimals: 2,
    status: 'manual_addition',
    confidence: 1.0,
  });

  // Handle Metadata change
  const handleMetadataChange = (field: string, val: any) => {
    onUpdateDraft({
      ...draft,
      metadata: {
        ...draft.metadata,
        [field]: val,
      },
    });
  };

  const handleConditionsChange = (field: string, val: string) => {
    onUpdateDraft({
      ...draft,
      metadata: {
        ...draft.metadata,
        conditions_nominales: {
          ...draft.metadata.conditions_nominales,
          [field]: val,
        },
      },
    });
  };

  // Normalise all units in draft
  const handleNormalizeAllUnits = () => {
    const updatedInputs = draft.extracted_inputs.map((inp) => ({
      ...inp,
      unit: normalizeUnit(inp.unit),
    }));
    const updatedFormulas = draft.extracted_formulas.map((form) => ({
      ...form,
      unit: normalizeUnit(form.unit),
    }));
    onUpdateDraft({
      ...draft,
      extracted_inputs: updatedInputs,
      extracted_formulas: updatedFormulas,
    });
  };

  // Add new input variable
  const handleAddInput = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newInput.key || !newInput.label) return;

    const formattedKey = newInput.key.toLowerCase().replace(/[^a-z0-9_]/g, '_');
    const inputToAdd: InputVariable = {
      id: `inp_custom_${Date.now()}`,
      key: formattedKey,
      label: newInput.label || formattedKey,
      symbol: newInput.symbol || formattedKey,
      unit: normalizeUnit(newInput.unit || 'mm'),
      type: (newInput.type as VariableType) || 'decimal',
      status: 'manual_addition',
      confidence: 1.0,
      defaultValue: newInput.defaultValue ?? 10,
      min: newInput.min,
      max: newInput.max,
      description: newInput.description || 'Ajouté manuellement par l opérateur',
    };

    onUpdateDraft({
      ...draft,
      extracted_inputs: [...draft.extracted_inputs, inputToAdd],
    });

    setNewInput({
      key: '',
      label: '',
      symbol: '',
      unit: 'mm',
      type: 'decimal',
      defaultValue: 10,
      min: 0,
      max: 1000,
      status: 'manual_addition',
      confidence: 1.0,
    });
    setShowAddInputModal(false);
  };

  // Remove input variable
  const handleRemoveInput = (id: string) => {
    onUpdateDraft({
      ...draft,
      extracted_inputs: draft.extracted_inputs.filter((inp) => inp.id !== id),
    });
  };

  // Update specific input
  const handleUpdateInput = (id: string, updates: Partial<InputVariable>) => {
    onUpdateDraft({
      ...draft,
      extracted_inputs: draft.extracted_inputs.map((inp) =>
        inp.id === id ? { ...inp, ...updates } : inp
      ),
    });
  };

  // Add new formula
  const handleAddFormula = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newFormula.output_key || !newFormula.label || !newFormula.raw_detected_formula) return;

    const formattedKey = newFormula.output_key.toLowerCase().replace(/[^a-z0-9_]/g, '_');
    const formulaToAdd: FormulaDefinition = {
      id: `form_custom_${Date.now()}`,
      output_key: formattedKey,
      label: newFormula.label,
      symbol: newFormula.symbol || formattedKey,
      unit: normalizeUnit(newFormula.unit || 'MPa'),
      raw_detected_formula: newFormula.raw_detected_formula,
      decimals: newFormula.decimals ?? 2,
      status: 'manual_addition',
      confidence: 1.0,
      description: newFormula.description || 'Formule ajoutée par l opérateur',
    };

    onUpdateDraft({
      ...draft,
      extracted_formulas: [...draft.extracted_formulas, formulaToAdd],
    });

    setNewFormula({
      output_key: '',
      label: '',
      symbol: '',
      unit: 'MPa',
      raw_detected_formula: '',
      decimals: 2,
      status: 'manual_addition',
      confidence: 1.0,
    });
    setShowAddFormulaModal(false);
  };

  // Update formula in draft
  const handleUpdateFormula = (updatedFormula: FormulaDefinition) => {
    onUpdateDraft({
      ...draft,
      extracted_formulas: draft.extracted_formulas.map((f) =>
        f.id === updatedFormula.id ? updatedFormula : f
      ),
    });
  };

  // Remove formula from draft
  const handleRemoveFormula = (id: string) => {
    onUpdateDraft({
      ...draft,
      extracted_formulas: draft.extracted_formulas.filter((f) => f.id !== id),
    });
  };

  // Deploy to ACTIVE status
  const handleFinalDeployment = () => {
    const deployedDraft: NormDraft = {
      ...draft,
      status: 'ACTIVE',
      updated_at: new Date().toISOString(),
      reviewed_by: 'Opérateur Qualité Laboratoire',
    };

    // Confetti celebration
    try {
      confetti({
        particleCount: 100,
        spread: 70,
        origin: { y: 0.6 },
      });
    } catch {
      // safe fallback
    }

    onDeployProtocol(deployedDraft);
  };

  const needsReviewCount =
    draft.extracted_inputs.filter((i) => i.status === 'needs_review').length +
    draft.extracted_formulas.filter((f) => f.status === 'needs_review').length;

  return (
    <div className="space-y-6 animate-in fade-in duration-200">
      {/* Editor Screen Header Bar */}
      <div className="bg-slate-900 border border-slate-800 rounded-2xl p-5 shadow-lg">
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-4">
          {/* Title & Back */}
          <div className="flex items-center space-x-3">
            <button
              onClick={onBackToDashboard}
              className="p-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 transition"
              title="Retour au Tableau de Bord"
            >
              <ArrowLeft className="w-4 h-4" />
            </button>

            <div>
              <div className="flex items-center space-x-2.5">
                <span className="px-2.5 py-0.5 text-xs font-bold font-mono rounded-md bg-blue-950 text-blue-300 border border-blue-800/60">
                  {draft.metadata.norme}
                </span>
                <h2 className="text-base font-bold text-white tracking-tight">
                  {draft.metadata.titre}
                </h2>
                <span className={`px-2 py-0.5 text-[11px] font-bold rounded-full border ${
                  draft.status === 'ACTIVE'
                    ? 'bg-emerald-950/80 text-emerald-300 border-emerald-700/60'
                    : 'bg-amber-950/80 text-amber-300 border-amber-700/60'
                }`}>
                  {draft.status === 'ACTIVE' ? '● ACTIF' : '● BROUILLON ASSISTÉ'}
                </span>
              </div>
              <p className="text-xs text-slate-400 mt-0.5">
                ID Draft : <span className="font-mono">{draft.draft_id}</span> • Domaine : <span className="text-slate-300">{draft.metadata.domaine}</span>
              </p>
            </div>
          </div>

          {/* Actions & Metrics */}
          <div className="flex flex-wrap items-center gap-2.5">
            <div className="flex items-center space-x-2 px-3 py-1.5 rounded-xl bg-slate-950 border border-slate-800 text-xs">
              <Sparkles className="w-3.5 h-3.5 text-cyan-400" />
              <span className="text-slate-400">Confiance Machine :</span>
              <span className="font-bold text-white">{Math.round(draft.metadata.confidence * 100)} %</span>
            </div>

            {needsReviewCount > 0 && (
              <div className="flex items-center space-x-1.5 px-3 py-1.5 rounded-xl bg-amber-950/60 border border-amber-800/60 text-xs text-amber-300 font-semibold">
                <AlertTriangle className="w-3.5 h-3.5" />
                <span>{needsReviewCount} champ(s) à valider</span>
              </div>
            )}

            <button
              onClick={onOpenJsonInspector}
              className="px-3 py-1.5 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition flex items-center space-x-1.5"
            >
              <Braces className="w-3.5 h-3.5 text-cyan-400" />
              <span>JSON Intermédiaire</span>
            </button>

            {draft.status !== 'ACTIVE' ? (
              <button
                onClick={handleFinalDeployment}
                className="px-4 py-2 rounded-xl text-xs font-semibold bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white shadow-md shadow-emerald-600/30 transition flex items-center space-x-1.5"
              >
                <ShieldCheck className="w-4 h-4" />
                <span>Déployer en Protocole ACTIVE</span>
              </button>
            ) : (
              <button
                onClick={handleFinalDeployment}
                className="px-4 py-2 rounded-xl text-xs font-semibold bg-blue-600 hover:bg-blue-500 text-white shadow-md transition flex items-center space-x-1.5"
              >
                <Save className="w-4 h-4" />
                <span>Mettre à Jour la BDD</span>
              </button>
            )}
          </div>
        </div>

        {/* 4-Step Guided Workflow Navigation */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-2 mt-5 pt-4 border-t border-slate-800">
          {[
            { step: 1, title: '1. Métadonnées', icon: FileText, desc: 'Nom, organisme, domaine' },
            { step: 2, title: '2. Revue des Variables', icon: Sliders, desc: `${draft.extracted_inputs.length} grandeurs d entrée` },
            { step: 3, title: '3. Pill Builder Formules', icon: Calculator, desc: `${draft.extracted_formulas.length} équations assemblées` },
            { step: 4, title: '4. Sandbox & Déploiement', icon: FlaskConical, desc: 'Validation sur éprouvette réelle' },
          ].map(({ step, title, icon: Icon, desc }) => (
            <button
              key={step}
              onClick={() => setCurrentStep(step as any)}
              className={`p-3 rounded-xl text-left border transition-all ${
                currentStep === step
                  ? 'bg-blue-600/20 border-blue-500/60 shadow-md shadow-blue-500/10'
                  : 'bg-slate-950/40 border-slate-800/80 hover:bg-slate-800/40 text-slate-400 hover:text-white'
              }`}
            >
              <div className="flex items-center space-x-2">
                <Icon className={`w-4 h-4 ${currentStep === step ? 'text-blue-400' : 'text-slate-500'}`} />
                <span className={`text-xs font-bold ${currentStep === step ? 'text-white' : 'text-slate-300'}`}>
                  {title}
                </span>
              </div>
              <p className="text-[11px] text-slate-400 mt-1 truncate">{desc}</p>
            </button>
          ))}
        </div>
      </div>

      {/* STEP 1: Metadata Verification */}
      {currentStep === 1 && (
        <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 space-y-6">
          <div className="flex items-center justify-between pb-4 border-b border-slate-800">
            <div>
              <h3 className="text-base font-bold text-white flex items-center space-x-2">
                <FileText className="w-5 h-5 text-blue-400" />
                <span>Étape 1 : Vérification & Rectification des Métadonnées</span>
              </h3>
              <p className="text-xs text-slate-400 mt-0.5">
                Vérifiez le code officiel de la norme, l organisme normalisateur et les conditions nominales d essai.
              </p>
            </div>
            <span className="text-xs px-2.5 py-1 rounded-lg bg-slate-800 text-blue-300 font-semibold border border-slate-700">
              Prise en charge machine : ~95 %
            </span>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <div>
              <label className="text-xs font-semibold text-slate-300 block mb-1.5">
                Code Officiel de la Norme :
              </label>
              <input
                type="text"
                value={draft.metadata.norme}
                onChange={(e) => handleMetadataChange('norme', e.target.value)}
                className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2.5 text-sm font-mono text-white focus:outline-none focus:border-blue-500"
              />
            </div>

            <div>
              <label className="text-xs font-semibold text-slate-300 block mb-1.5">
                Organisme Normalisateur :
              </label>
              <input
                type="text"
                value={draft.metadata.organisme || ''}
                onChange={(e) => handleMetadataChange('organisme', e.target.value)}
                placeholder="Ex: ISO / AFNOR / ASTM / CEN"
                className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-white focus:outline-none focus:border-blue-500"
              />
            </div>

            <div className="md:col-span-2">
              <label className="text-xs font-semibold text-slate-300 block mb-1.5">
                Titre Complet du Protocole :
              </label>
              <input
                type="text"
                value={draft.metadata.titre}
                onChange={(e) => handleMetadataChange('titre', e.target.value)}
                className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-white focus:outline-none focus:border-blue-500"
              />
            </div>

            <div>
              <label className="text-xs font-semibold text-slate-300 block mb-1.5">
                Domaine d Application / Matériau :
              </label>
              <input
                type="text"
                value={draft.metadata.domaine}
                onChange={(e) => handleMetadataChange('domaine', e.target.value)}
                className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-white focus:outline-none focus:border-blue-500"
              />
            </div>

            <div>
              <label className="text-xs font-semibold text-slate-300 block mb-1.5">
                Millésime / Année d Édition :
              </label>
              <input
                type="text"
                value={draft.metadata.annee_edition || ''}
                onChange={(e) => handleMetadataChange('annee_edition', e.target.value)}
                placeholder="Ex: 2012 (R2019)"
                className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-white focus:outline-none focus:border-blue-500"
              />
            </div>

            <div className="md:col-span-2">
              <label className="text-xs font-semibold text-slate-300 block mb-1.5">
                Description & Résumé Technique du Protocole :
              </label>
              <textarea
                rows={3}
                value={draft.metadata.description || ''}
                onChange={(e) => handleMetadataChange('description', e.target.value)}
                className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3.5 py-2.5 text-sm text-white focus:outline-none focus:border-blue-500"
              />
            </div>
          </div>

          {/* Nominal Test Conditions */}
          <div className="pt-4 border-t border-slate-800">
            <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-3">
              Conditions Environnementales Nominales d Essai
            </h4>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div>
                <label className="text-xs text-slate-300 block mb-1">Température nominale :</label>
                <input
                  type="text"
                  value={draft.metadata.conditions_nominales?.temperature || '23 ± 2 °C'}
                  onChange={(e) => handleConditionsChange('temperature', e.target.value)}
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                />
              </div>

              <div>
                <label className="text-xs text-slate-300 block mb-1">Hygrométrie nominale :</label>
                <input
                  type="text"
                  value={draft.metadata.conditions_nominales?.hygrometrie || '50 ± 10 % HR'}
                  onChange={(e) => handleConditionsChange('hygrometrie', e.target.value)}
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                />
              </div>

              <div>
                <label className="text-xs text-slate-300 block mb-1">Vitesse d essai :</label>
                <input
                  type="text"
                  value={draft.metadata.conditions_nominales?.vitesse_essai || '50 mm/min'}
                  onChange={(e) => handleConditionsChange('vitesse_essai', e.target.value)}
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                />
              </div>
            </div>
          </div>

          {/* Step 1 Footer */}
          <div className="flex justify-end pt-4 border-t border-slate-800">
            <button
              onClick={() => setCurrentStep(2)}
              className="px-5 py-2.5 rounded-xl text-xs font-semibold bg-blue-600 hover:bg-blue-500 text-white shadow-md transition flex items-center space-x-2"
            >
              <span>Continuer vers la Revue des Variables</span>
              <ArrowRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      {/* STEP 2: Input Variables Review & Unit Normalization */}
      {currentStep === 2 && (
        <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 space-y-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-800">
            <div>
              <h3 className="text-base font-bold text-white flex items-center space-x-2">
                <Sliders className="w-5 h-5 text-cyan-400" />
                <span>Étape 2 : Revue des Variables d Entrée (Inputs)</span>
              </h3>
              <p className="text-xs text-slate-400 mt-0.5">
                Rectifiez les unités mal lues, ajustez les bornes min/max et ajoutez les champs d essai manquants.
              </p>
            </div>

            <div className="flex items-center space-x-2">
              <button
                onClick={handleNormalizeAllUnits}
                className="px-3 py-2 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-cyan-300 border border-cyan-800/40 transition flex items-center space-x-1.5"
                title="Convertit automatiquement KN en kN, N/mm2 en MPa, etc."
              >
                <RefreshCw className="w-3.5 h-3.5" />
                <span>Normaliser les Unités</span>
              </button>

              <button
                onClick={() => setShowAddInputModal(true)}
                className="px-3 py-2 rounded-xl text-xs font-semibold bg-blue-600 hover:bg-blue-500 text-white transition flex items-center space-x-1.5"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>+ Ajouter une Variable</span>
              </button>
            </div>
          </div>

          {/* Variables Table */}
          <div className="overflow-x-auto rounded-xl border border-slate-800">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-950 text-slate-300 border-b border-slate-800 uppercase text-[10px] tracking-wider">
                <tr>
                  <th className="py-3 px-4">Clé & Symbole</th>
                  <th className="py-3 px-4">Libellé</th>
                  <th className="py-3 px-4">Unité Normalisée</th>
                  <th className="py-3 px-4">Type</th>
                  <th className="py-3 px-4">Valeur par Défaut / Bornes</th>
                  <th className="py-3 px-4">Statut Extraction</th>
                  <th className="py-3 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800 bg-slate-900/60">
                {draft.extracted_inputs.map((inp) => (
                  <tr key={inp.id} className="hover:bg-slate-800/40 transition-colors">
                    <td className="py-3 px-4">
                      <div className="font-mono font-bold text-white">{inp.key}</div>
                      <div className="text-[11px] text-cyan-400 font-serif">
                        Symbole : <strong className="text-white">{inp.symbol || inp.key}</strong>
                      </div>
                    </td>
                    <td className="py-3 px-4 text-slate-200 font-medium">
                      {inp.label}
                    </td>
                    <td className="py-3 px-4">
                      <select
                        value={inp.unit}
                        onChange={(e) => handleUpdateInput(inp.id, { unit: e.target.value })}
                        className="bg-slate-950 border border-slate-700 text-xs rounded-lg px-2 py-1 text-cyan-300 font-mono focus:outline-none focus:border-blue-500 font-semibold"
                      >
                        {['mm', 'cm', 'm', 'N', 'kN', 'MPa', 'kPa', 'bar', 'g', 'kg', '%', '°C', 'mm²'].map(
                          (u) => (
                            <option key={u} value={u}>
                              {u}
                            </option>
                          )
                        )}
                      </select>
                    </td>
                    <td className="py-3 px-4 text-slate-300 font-mono text-[11px]">
                      {inp.type}
                    </td>
                    <td className="py-3 px-4">
                      <div className="font-mono text-slate-200">
                        Def: {inp.defaultValue !== undefined ? inp.defaultValue : '—'}
                      </div>
                      {inp.min !== undefined && inp.max !== undefined && (
                        <div className="text-[10px] text-slate-500">
                          [{inp.min} - {inp.max}]
                        </div>
                      )}
                    </td>
                    <td className="py-3 px-4">
                      {inp.status === 'verified' ? (
                        <span className="inline-flex items-center space-x-1 px-2 py-0.5 rounded-full text-[11px] font-semibold bg-emerald-500/10 text-emerald-300 border border-emerald-500/30">
                          <Check className="w-3 h-3" />
                          <span>verified ({Math.round(inp.confidence * 100)}%)</span>
                        </span>
                      ) : inp.status === 'needs_review' ? (
                        <span className="inline-flex items-center space-x-1 px-2 py-0.5 rounded-full text-[11px] font-semibold bg-amber-500/10 text-amber-300 border border-amber-500/30">
                          <AlertTriangle className="w-3 h-3" />
                          <span>needs_review</span>
                        </span>
                      ) : (
                        <span className="inline-flex items-center space-x-1 px-2 py-0.5 rounded-full text-[11px] font-semibold bg-indigo-500/10 text-indigo-300 border border-indigo-500/30">
                          <Plus className="w-3 h-3" />
                          <span>ajouté</span>
                        </span>
                      )}
                    </td>
                    <td className="py-3 px-4 text-right">
                      <button
                        onClick={() => handleRemoveInput(inp.id)}
                        className="p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-rose-400 transition"
                        title="Supprimer cette variable"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Step 2 Footer */}
          <div className="flex justify-between items-center pt-4 border-t border-slate-800">
            <button
              onClick={() => setCurrentStep(1)}
              className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white transition flex items-center space-x-1.5"
            >
              <ArrowLeft className="w-4 h-4" />
              <span>Précédent (Métadonnées)</span>
            </button>
            <button
              onClick={() => setCurrentStep(3)}
              className="px-5 py-2.5 rounded-xl text-xs font-semibold bg-blue-600 hover:bg-blue-500 text-white shadow-md transition flex items-center space-x-2"
            >
              <span>Continuer vers le Pill Builder de Formules</span>
              <ArrowRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      {/* STEP 3: Formula Adjustment via No-Code Pill Builder */}
      {currentStep === 3 && (
        <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 space-y-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-800">
            <div>
              <h3 className="text-base font-bold text-white flex items-center space-x-2">
                <Calculator className="w-5 h-5 text-indigo-400" />
                <span>Étape 3 : Ajustement des Formules (Pill Builder No-Code)</span>
              </h3>
              <p className="text-xs text-slate-400 mt-0.5">
                Les équations détectées avec le statut <strong className="text-amber-400">needs_review</strong> sont surlignées. Utilisez les puces interactives pour reconstituer l équation sans risque d erreur de syntaxe.
              </p>
            </div>

            <button
              onClick={() => setShowAddFormulaModal(true)}
              className="px-3.5 py-2 rounded-xl text-xs font-semibold bg-blue-600 hover:bg-blue-500 text-white transition flex items-center space-x-1.5"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>+ Ajouter une Formule</span>
            </button>
          </div>

          {/* List of Formula Pill Builders */}
          <div className="space-y-5">
            {draft.extracted_formulas.map((form) => (
              <div key={form.id} className="relative">
                <PillFormulaBuilder
                  formula={form}
                  availableInputs={draft.extracted_inputs}
                  otherFormulas={draft.extracted_formulas}
                  onUpdateFormula={handleUpdateFormula}
                />
                {draft.extracted_formulas.length > 1 && (
                  <button
                    onClick={() => handleRemoveFormula(form.id)}
                    className="absolute top-4 right-28 p-1 rounded hover:bg-slate-800 text-slate-400 hover:text-rose-400 transition"
                    title="Supprimer cette formule"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                )}
              </div>
            ))}
          </div>

          {/* Step 3 Footer */}
          <div className="flex justify-between items-center pt-4 border-t border-slate-800">
            <button
              onClick={() => setCurrentStep(2)}
              className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white transition flex items-center space-x-1.5"
            >
              <ArrowLeft className="w-4 h-4" />
              <span>Précédent (Variables)</span>
            </button>
            <button
              onClick={() => setCurrentStep(4)}
              className="px-5 py-2.5 rounded-xl text-xs font-semibold bg-blue-600 hover:bg-blue-500 text-white shadow-md transition flex items-center space-x-2"
            >
              <span>Continuer vers la Validation Sandbox</span>
              <ArrowRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      {/* STEP 4: Sandbox Validation & Final Deployment */}
      {currentStep === 4 && (
        <div className="space-y-6">
          <SandboxRunner draft={draft} onUpdateDraft={onUpdateDraft} />

          {/* Deployment CTA Box */}
          <div className="bg-gradient-to-r from-blue-950 via-slate-900 to-indigo-950 border border-blue-800/60 rounded-2xl p-6 flex flex-col sm:flex-row sm:items-center justify-between gap-4 shadow-xl">
            <div>
              <div className="flex items-center space-x-2">
                <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                <h4 className="text-base font-bold text-white">
                  Prêt pour le Déploiement en Base de Données PycnoLab
                </h4>
              </div>
              <p className="text-xs text-slate-300 mt-1 max-w-2xl leading-relaxed">
                Après confirmation, le protocole passe au statut <strong className="text-emerald-400">ACTIVE</strong>. Il sera immédiatement accessible dans le laboratoire pour toutes les saisies d essais officielles.
              </p>
            </div>

            <button
              onClick={handleFinalDeployment}
              className="px-6 py-3 rounded-xl text-sm font-bold bg-gradient-to-r from-emerald-500 to-teal-500 hover:from-emerald-400 hover:to-teal-400 text-white shadow-lg shadow-emerald-500/30 transition transform hover:-translate-y-0.5 flex items-center space-x-2 whitespace-nowrap"
            >
              <ShieldCheck className="w-5 h-5" />
              <span>Valider & Déployer (100% Fiable)</span>
            </button>
          </div>
        </div>
      )}

      {/* Modal: Add New Input Variable */}
      {showAddInputModal && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl max-w-lg w-full p-6 space-y-4 shadow-2xl">
            <h4 className="text-base font-bold text-white flex items-center space-x-2">
              <Plus className="w-5 h-5 text-blue-400" />
              <span>Ajouter une Variable d Entrée (Input)</span>
            </h4>

            <form onSubmit={handleAddInput} className="space-y-3.5">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-slate-300 block mb-1">Clé interne (snake_case) :</label>
                  <input
                    type="text"
                    required
                    value={newInput.key}
                    onChange={(e) => setNewInput({ ...newInput, key: e.target.value })}
                    placeholder="Ex: longueur_l0"
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs font-mono text-white"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-slate-300 block mb-1">Symbole scientifique :</label>
                  <input
                    type="text"
                    value={newInput.symbol}
                    onChange={(e) => setNewInput({ ...newInput, symbol: e.target.value })}
                    placeholder="Ex: L_0"
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs font-mono text-white"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-300 block mb-1">Libellé complet :</label>
                <input
                  type="text"
                  required
                  value={newInput.label}
                  onChange={(e) => setNewInput({ ...newInput, label: e.target.value })}
                  placeholder="Ex: Longueur initiale entre repères"
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                />
              </div>

              <div className="grid grid-cols-3 gap-3">
                <div>
                  <label className="text-xs font-semibold text-slate-300 block mb-1">Unité :</label>
                  <input
                    type="text"
                    value={newInput.unit}
                    onChange={(e) => setNewInput({ ...newInput, unit: e.target.value })}
                    placeholder="Ex: mm, kN, MPa"
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-cyan-300 font-mono"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-slate-300 block mb-1">Type :</label>
                  <select
                    value={newInput.type}
                    onChange={(e) => setNewInput({ ...newInput, type: e.target.value as any })}
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                  >
                    <option value="decimal">decimal</option>
                    <option value="integer">integer</option>
                    <option value="select">select</option>
                  </select>
                </div>
                <div>
                  <label className="text-xs font-semibold text-slate-300 block mb-1">Valeur par défaut :</label>
                  <input
                    type="number"
                    step="any"
                    value={newInput.defaultValue}
                    onChange={(e) => setNewInput({ ...newInput, defaultValue: parseFloat(e.target.value) })}
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white font-mono"
                  />
                </div>
              </div>

              <div className="flex items-center justify-end space-x-3 pt-3">
                <button
                  type="button"
                  onClick={() => setShowAddInputModal(false)}
                  className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white transition"
                >
                  Annuler
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl text-xs font-semibold bg-blue-600 hover:bg-blue-500 text-white transition"
                >
                  Ajouter la Variable
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Add New Formula */}
      {showAddFormulaModal && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-700 rounded-2xl max-w-lg w-full p-6 space-y-4 shadow-2xl">
            <h4 className="text-base font-bold text-white flex items-center space-x-2">
              <Plus className="w-5 h-5 text-indigo-400" />
              <span>Ajouter une Formule de Calcul</span>
            </h4>

            <form onSubmit={handleAddFormula} className="space-y-3.5">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-slate-300 block mb-1">Clé de sortie (snake_case) :</label>
                  <input
                    type="text"
                    required
                    value={newFormula.output_key}
                    onChange={(e) => setNewFormula({ ...newFormula, output_key: e.target.value })}
                    placeholder="Ex: module_young_et"
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs font-mono text-white"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-slate-300 block mb-1">Symbole scientifique :</label>
                  <input
                    type="text"
                    value={newFormula.symbol}
                    onChange={(e) => setNewFormula({ ...newFormula, symbol: e.target.value })}
                    placeholder="Ex: E_t"
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs font-mono text-white"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-300 block mb-1">Libellé du résultat :</label>
                <input
                  type="text"
                  required
                  value={newFormula.label}
                  onChange={(e) => setNewFormula({ ...newFormula, label: e.target.value })}
                  placeholder="Ex: Module d élasticité en traction"
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-slate-300 block mb-1">Unité du résultat :</label>
                  <input
                    type="text"
                    value={newFormula.unit}
                    onChange={(e) => setNewFormula({ ...newFormula, unit: e.target.value })}
                    placeholder="Ex: MPa, %, g/cm³"
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-cyan-300 font-mono"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-slate-300 block mb-1">Décimales d affichage :</label>
                  <input
                    type="number"
                    min="0"
                    max="6"
                    value={newFormula.decimals}
                    onChange={(e) => setNewFormula({ ...newFormula, decimals: parseInt(e.target.value) })}
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white font-mono"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-300 block mb-1">Formule mathématique :</label>
                <input
                  type="text"
                  required
                  value={newFormula.raw_detected_formula}
                  onChange={(e) => setNewFormula({ ...newFormula, raw_detected_formula: e.target.value })}
                  placeholder="Ex: (sigma_2 - sigma_1) / (epsilon_2 - epsilon_1)"
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs font-mono text-cyan-300"
                />
              </div>

              <div className="flex items-center justify-end space-x-3 pt-3">
                <button
                  type="button"
                  onClick={() => setShowAddFormulaModal(false)}
                  className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white transition"
                >
                  Annuler
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-xl text-xs font-semibold bg-indigo-600 hover:bg-indigo-500 text-white transition"
                >
                  Ajouter la Formule
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
