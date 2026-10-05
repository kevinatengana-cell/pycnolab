import React, { useState, useEffect } from 'react';
import { 
  FormulaDefinition, 
  InputVariable, 
  FormulaPill, 
  PillCategory 
} from '../types';
import { 
  tokenizeFormulaToPills, 
  pillsToFormulaString, 
  validateFormulaSyntax, 
  evaluateFormulaClient 
} from '../utils/formulaUtils';
import { 
  Check, 
  AlertTriangle, 
  Plus, 
  Trash2, 
  RotateCcw, 
  Code2, 
  Sparkles, 
  HelpCircle,
  Hash,
  Calculator,
  ArrowRight
} from 'lucide-react';

interface PillFormulaBuilderProps {
  formula: FormulaDefinition;
  availableInputs: InputVariable[];
  otherFormulas?: FormulaDefinition[];
  onUpdateFormula: (updated: FormulaDefinition) => void;
}

export const PillFormulaBuilder: React.FC<PillFormulaBuilderProps> = ({
  formula,
  availableInputs,
  otherFormulas = [],
  onUpdateFormula,
}) => {
  const [pills, setPills] = useState<FormulaPill[]>([]);
  const [isDirectMode, setIsDirectMode] = useState(false);
  const [directText, setDirectText] = useState(formula.raw_detected_formula || '');
  const [customNumber, setCustomNumber] = useState('');

  // Combined available variables (inputs + other formula outputs prior to this one)
  const allAvailableKeys = [
    ...availableInputs.map((inp) => inp.key),
    ...otherFormulas
      .filter((f) => f.id !== formula.id && f.output_key)
      .map((f) => f.output_key),
  ];

  // Initialize pills on formula change
  useEffect(() => {
    const initialPills = tokenizeFormulaToPills(
      formula.raw_detected_formula || '',
      availableInputs
    );
    setPills(initialPills);
    setDirectText(formula.raw_detected_formula || '');
  }, [formula.id, formula.raw_detected_formula]);

  const currentFormulaStr = isDirectMode ? directText : pillsToFormulaString(pills);
  const validation = validateFormulaSyntax(currentFormulaStr, allAvailableKeys);

  // Compute a sample test value using input default values
  let previewResult: number | null = null;
  let previewError: string | null = null;
  try {
    const sampleVals: Record<string, number> = {};
    availableInputs.forEach((inp) => {
      sampleVals[inp.key] = inp.defaultValue !== undefined ? inp.defaultValue : 10;
    });
    previewResult = evaluateFormulaClient(currentFormulaStr, sampleVals);
  } catch (err: any) {
    previewError = err.message;
  }

  // Update parent state
  const syncUpdate = (newFormulaStr: string, newPills?: FormulaPill[]) => {
    const isValid = validateFormulaSyntax(newFormulaStr, allAvailableKeys).isValid;
    onUpdateFormula({
      ...formula,
      raw_detected_formula: newFormulaStr,
      pills: newPills || tokenizeFormulaToPills(newFormulaStr, availableInputs),
      status: isValid ? 'verified' : 'needs_review',
    });
  };

  const handleAddPill = (
    category: PillCategory,
    value: string,
    text: string,
    symbol?: string
  ) => {
    const newPill: FormulaPill = {
      id: `pill_${Date.now()}_${Math.random().toString(36).substr(2, 4)}`,
      category,
      value,
      text,
      symbol,
    };
    const nextPills = [...pills, newPill];
    setPills(nextPills);
    const newFormulaStr = pillsToFormulaString(nextPills);
    setDirectText(newFormulaStr);
    syncUpdate(newFormulaStr, nextPills);
  };

  const handleRemovePill = (indexToRemove: number) => {
    const nextPills = pills.filter((_, idx) => idx !== indexToRemove);
    setPills(nextPills);
    const newFormulaStr = pillsToFormulaString(nextPills);
    setDirectText(newFormulaStr);
    syncUpdate(newFormulaStr, nextPills);
  };

  const handleClearAll = () => {
    setPills([]);
    setDirectText('');
    syncUpdate('', []);
  };

  const handleResetToDetected = () => {
    const initial = tokenizeFormulaToPills(formula.raw_detected_formula || '', availableInputs);
    setPills(initial);
    setDirectText(formula.raw_detected_formula || '');
    syncUpdate(formula.raw_detected_formula || '', initial);
  };

  const handleDirectTextChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value;
    setDirectText(val);
    const newPills = tokenizeFormulaToPills(val, availableInputs);
    setPills(newPills);
    syncUpdate(val, newPills);
  };

  const handleAddCustomNumber = (e: React.FormEvent) => {
    e.preventDefault();
    if (!customNumber || isNaN(Number(customNumber))) return;
    handleAddPill('number', customNumber, customNumber);
    setCustomNumber('');
  };

  return (
    <div className={`p-4 sm:p-5 rounded-xl border transition-all ${
      formula.status === 'needs_review'
        ? 'bg-amber-950/20 border-amber-500/40 shadow-sm shadow-amber-900/10'
        : 'bg-slate-900/90 border-slate-800 shadow-sm'
    }`}>
      {/* Formula Header & Status */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4 pb-3 border-b border-slate-800">
        <div className="flex items-center space-x-3">
          <div className="w-8 h-8 rounded-lg bg-indigo-500/20 text-indigo-400 flex items-center justify-center font-serif font-bold text-sm">
            {formula.symbol || 'fx'}
          </div>
          <div>
            <div className="flex items-center space-x-2">
              <span className="font-bold text-white text-sm">{formula.label}</span>
              <span className="text-xs font-mono text-slate-400">({formula.output_key})</span>
              <span className="px-1.5 py-0.5 text-[10px] font-bold rounded bg-slate-800 text-blue-300 border border-slate-700">
                {formula.unit || 'MPa'}
              </span>
            </div>
            {formula.description && (
              <p className="text-[11px] text-slate-400 mt-0.5">{formula.description}</p>
            )}
          </div>
        </div>

        <div className="flex items-center space-x-2">
          {formula.status === 'needs_review' ? (
            <span className="inline-flex items-center space-x-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-amber-500/10 text-amber-300 border border-amber-500/30">
              <AlertTriangle className="w-3.5 h-3.5" />
              <span>needs_review</span>
            </span>
          ) : (
            <span className="inline-flex items-center space-x-1 px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-500/10 text-emerald-300 border border-emerald-500/30">
              <Check className="w-3.5 h-3.5" />
              <span>vérifiée</span>
            </span>
          )}

          <button
            onClick={() => setIsDirectMode(!isDirectMode)}
            className="px-2.5 py-1 rounded-lg text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-300 transition flex items-center space-x-1 border border-slate-700"
            title="Basculer entre le mode Puces No-Code et le mode Texte Direct"
          >
            <Code2 className="w-3.5 h-3.5" />
            <span>{isDirectMode ? 'Mode Puces' : 'Mode Texte'}</span>
          </button>
        </div>
      </div>

      {/* Pill Expression Canvas / Text Editor */}
      <div className="mb-4">
        <div className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider mb-1.5 flex items-center justify-between">
          <span>Expression Mathématique Assemblée</span>
          <div className="flex items-center space-x-2">
            <button
              onClick={handleResetToDetected}
              className="text-[10px] text-slate-400 hover:text-slate-200 transition flex items-center space-x-1"
            >
              <RotateCcw className="w-3 h-3" />
              <span>Réinitialiser</span>
            </button>
            <button
              onClick={handleClearAll}
              className="text-[10px] text-rose-400 hover:text-rose-300 transition flex items-center space-x-1"
            >
              <Trash2 className="w-3 h-3" />
              <span>Effacer</span>
            </button>
          </div>
        </div>

        {isDirectMode ? (
          <div className="relative">
            <input
              type="text"
              value={directText}
              onChange={handleDirectTextChange}
              placeholder="Ex: force_f / (largeur_b * epaisseur_h)"
              className="w-full bg-slate-950 border border-slate-700 rounded-xl px-4 py-3 text-sm font-mono text-cyan-300 focus:outline-none focus:border-blue-500 shadow-inner"
            />
          </div>
        ) : (
          <div className="min-h-[56px] p-2.5 bg-slate-950 rounded-xl border border-slate-800/80 flex flex-wrap items-center gap-1.5 shadow-inner">
            {pills.length === 0 ? (
              <span className="text-xs text-slate-500 italic p-1">
                Cliquez sur les puces ci-dessous pour assembler votre équation sans erreur de syntaxe...
              </span>
            ) : (
              pills.map((pill, idx) => {
                let pillStyle = 'bg-slate-800 text-slate-200 border-slate-700';
                if (pill.category === 'variable') {
                  pillStyle = 'bg-blue-600/30 text-blue-200 border-blue-500/50 hover:bg-blue-600/40';
                } else if (pill.category === 'operator') {
                  pillStyle = 'bg-amber-600/20 text-amber-200 border-amber-500/40 font-bold';
                } else if (pill.category === 'parenthesis') {
                  pillStyle = 'bg-purple-600/20 text-purple-200 border-purple-500/40 font-bold';
                } else if (pill.category === 'number') {
                  pillStyle = 'bg-cyan-600/20 text-cyan-200 border-cyan-500/40 font-mono';
                } else if (pill.category === 'function') {
                  pillStyle = 'bg-emerald-600/20 text-emerald-200 border-emerald-500/40 font-mono';
                }

                return (
                  <div
                    key={pill.id || idx}
                    className={`group inline-flex items-center space-x-1.5 px-2.5 py-1 rounded-lg text-xs border font-medium transition shadow-sm ${pillStyle}`}
                  >
                    <span>{pill.text}</span>
                    <button
                      type="button"
                      onClick={() => handleRemovePill(idx)}
                      className="text-slate-400 hover:text-rose-400 transition ml-0.5 p-0.5 rounded"
                      title="Supprimer cette puce"
                    >
                      ×
                    </button>
                  </div>
                );
              })
            )}
          </div>
        )}

        {/* Validation Status Bar */}
        <div className="mt-2 flex flex-wrap items-center justify-between text-xs gap-2">
          {validation.isValid ? (
            <div className="flex items-center space-x-1.5 text-emerald-400 font-medium">
              <Check className="w-3.5 h-3.5" />
              <span>Syntaxe mathématique valide</span>
              {previewResult !== null && (
                <span className="text-slate-400 ml-2 font-mono text-[11px]">
                  (Évaluation témoin = <strong className="text-white">{previewResult.toFixed(formula.decimals ?? 2)} {formula.unit}</strong>)
                </span>
              )}
            </div>
          ) : (
            <div className="flex items-center space-x-1.5 text-rose-400 font-medium">
              <AlertTriangle className="w-3.5 h-3.5 flex-shrink-0" />
              <span>{validation.message}</span>
            </div>
          )}

          <div className="text-[11px] text-slate-400 font-mono">
            Formule brute : <span className="text-cyan-300">{currentFormulaStr || '—'}</span>
          </div>
        </div>
      </div>

      {/* Interactive Pill Palette */}
      <div className="space-y-3 pt-3 border-t border-slate-800/80">
        {/* Available Variables */}
        <div>
          <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1.5">
            1. Grandeurs d Entrée Disponibles (Cliquez pour insérer) :
          </span>
          <div className="flex flex-wrap gap-1.5">
            {availableInputs.map((inp) => (
              <button
                key={inp.id}
                type="button"
                onClick={() =>
                  handleAddPill(
                    'variable',
                    inp.key,
                    inp.symbol ? `${inp.label} (${inp.symbol})` : inp.label,
                    inp.symbol
                  )
                }
                className="px-2.5 py-1 rounded-lg text-xs bg-blue-950/60 hover:bg-blue-900/80 text-blue-200 border border-blue-700/50 transition flex items-center space-x-1 shadow-sm transform hover:-translate-y-0.5"
              >
                <Plus className="w-3 h-3 text-blue-400" />
                <span className="font-semibold">{inp.symbol || inp.label}</span>
                <span className="text-[10px] text-blue-400/80">({inp.unit})</span>
              </button>
            ))}

            {otherFormulas
              .filter((f) => f.id !== formula.id && f.output_key)
              .map((f) => (
                <button
                  key={f.id}
                  type="button"
                  onClick={() =>
                    handleAddPill(
                      'variable',
                      f.output_key,
                      `${f.label} (${f.symbol || f.output_key})`,
                      f.symbol
                    )
                  }
                  className="px-2.5 py-1 rounded-lg text-xs bg-indigo-950/60 hover:bg-indigo-900/80 text-indigo-200 border border-indigo-700/50 transition flex items-center space-x-1 shadow-sm"
                >
                  <Plus className="w-3 h-3 text-indigo-400" />
                  <span className="font-semibold">{f.symbol || f.output_key}</span>
                  <span className="text-[10px] text-indigo-400/80">({f.unit})</span>
                </button>
              ))}
          </div>
        </div>

        {/* Operators & Symbols */}
        <div className="flex flex-wrap items-center gap-3">
          <div>
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              2. Opérateurs & Parenthèses :
            </span>
            <div className="flex flex-wrap gap-1">
              {[
                { op: '+', label: '+' },
                { op: '-', label: '−' },
                { op: '*', label: '×' },
                { op: '/', label: '÷' },
                { op: '^', label: 'xʸ (^)' },
                { op: '(', label: '(' },
                { op: ')', label: ')' },
              ].map(({ op, label }) => (
                <button
                  key={op}
                  type="button"
                  onClick={() =>
                    handleAddPill(
                      op === '(' || op === ')' ? 'parenthesis' : 'operator',
                      op,
                      label
                    )
                  }
                  className="w-8 h-7 rounded-lg text-xs font-bold bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition flex items-center justify-center shadow-sm active:scale-95"
                >
                  {label}
                </button>
              ))}
            </div>
          </div>

          {/* Math Functions & Constants */}
          <div>
            <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider block mb-1">
              3. Constantes & Fonctions :
            </span>
            <div className="flex flex-wrap items-center gap-1.5">
              {['1.5', '2', '3', '100', '1000', '0.5'].map((num) => (
                <button
                  key={num}
                  type="button"
                  onClick={() => handleAddPill('number', num, num)}
                  className="px-2 py-1 rounded-lg text-xs font-mono font-semibold bg-cyan-950/50 hover:bg-cyan-900/70 text-cyan-300 border border-cyan-800/40 transition shadow-sm"
                >
                  {num}
                </button>
              ))}

              <button
                type="button"
                onClick={() => handleAddPill('function', 'sqrt', 'sqrt')}
                className="px-2 py-1 rounded-lg text-xs font-mono font-semibold bg-emerald-950/50 hover:bg-emerald-900/70 text-emerald-300 border border-emerald-800/40 transition shadow-sm"
              >
                √ sqrt
              </button>

              <form onSubmit={handleAddCustomNumber} className="flex items-center space-x-1 ml-2">
                <input
                  type="text"
                  placeholder="Autre valeur..."
                  value={customNumber}
                  onChange={(e) => setCustomNumber(e.target.value)}
                  className="w-20 px-2 py-1 rounded-lg text-xs bg-slate-950 border border-slate-700 text-white focus:outline-none focus:border-cyan-500"
                />
                <button
                  type="submit"
                  disabled={!customNumber}
                  className="px-2 py-1 rounded-lg text-xs bg-slate-800 hover:bg-slate-700 text-white disabled:opacity-40 transition"
                >
                  +
                </button>
              </form>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
