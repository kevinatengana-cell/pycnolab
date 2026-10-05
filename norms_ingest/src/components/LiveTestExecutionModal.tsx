import React, { useState, useEffect } from 'react';
import { NormDraft } from '../types';
import { evaluateFormulaClient } from '../utils/formulaUtils';
import { 
  FlaskConical, 
  X, 
  Play, 
  CheckCircle2, 
  AlertCircle, 
  Printer, 
  Download, 
  FileCheck,
  Building,
  User,
  Calendar,
  Hash
} from 'lucide-react';

interface LiveTestExecutionModalProps {
  isOpen: boolean;
  onClose: () => void;
  protocol: NormDraft | null;
}

export const LiveTestExecutionModal: React.FC<LiveTestExecutionModalProps> = ({
  isOpen,
  onClose,
  protocol,
}) => {
  const [sampleId, setSampleId] = useState(`ECH-${new Date().getFullYear()}-001`);
  const [operatorName, setOperatorName] = useState('Technicien Laboratoire (PycnoLab)');
  const [testBatch, setTestBatch] = useState('Lot 2026-A1');
  const [inputValues, setInputValues] = useState<Record<string, number>>({});
  const [outputs, setOutputs] = useState<Record<string, number>>({});
  const [calcErrors, setCalcErrors] = useState<Record<string, string>>({});
  const [isTestRun, setIsTestRun] = useState(false);

  useEffect(() => {
    if (protocol) {
      const initial: Record<string, number> = {};
      protocol.extracted_inputs.forEach((inp) => {
        initial[inp.key] = inp.defaultValue !== undefined ? inp.defaultValue : 10;
      });
      setInputValues(initial);
      setIsTestRun(false);
    }
  }, [protocol]);

  if (!isOpen || !protocol) return null;

  const handleCompute = () => {
    const computedOuts: Record<string, number> = {};
    const errors: Record<string, string> = {};
    const scope = { ...inputValues };

    protocol.extracted_formulas.forEach((f) => {
      try {
        const res = evaluateFormulaClient(f.raw_detected_formula, scope);
        computedOuts[f.output_key] = res;
        scope[f.output_key] = res;
      } catch (err: any) {
        errors[f.output_key] = err.message || 'Erreur';
      }
    });

    setOutputs(computedOuts);
    setCalcErrors(errors);
    setIsTestRun(true);
  };

  const handlePrintCertificate = () => {
    window.print();
  };

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-black/75 backdrop-blur-sm flex items-center justify-center p-4 sm:p-6 animate-in fade-in duration-200">
      <div className="bg-slate-900 border border-slate-700 rounded-3xl w-full max-w-4xl overflow-hidden shadow-2xl flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-850 flex-shrink-0">
          <div className="flex items-center space-x-3">
            <div className="w-9 h-9 rounded-xl bg-emerald-500/20 text-emerald-400 flex items-center justify-center">
              <FlaskConical className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-white flex items-center space-x-2">
                <span>Saisie d Essai Officiel de Laboratoire</span>
                <span className="text-xs px-2 py-0.5 rounded font-mono bg-blue-950 text-blue-300 border border-blue-800">
                  {protocol.metadata.norme}
                </span>
              </h3>
              <p className="text-xs text-slate-400">
                Protocole certifié ({protocol.metadata.titre})
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Modal Body */}
        <div className="p-6 overflow-y-auto space-y-6 flex-1">
          {/* Specimen Identification Header */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 bg-slate-950 p-4 rounded-2xl border border-slate-800">
            <div>
              <label className="text-xs text-slate-400 block mb-1 flex items-center space-x-1">
                <Hash className="w-3.5 h-3.5 text-blue-400" />
                <span>Identifiant Éprouvette / Échantillon :</span>
              </label>
              <input
                type="text"
                value={sampleId}
                onChange={(e) => setSampleId(e.target.value)}
                className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs font-mono text-white"
              />
            </div>

            <div>
              <label className="text-xs text-slate-400 block mb-1 flex items-center space-x-1">
                <Building className="w-3.5 h-3.5 text-cyan-400" />
                <span>Lot de Production / Fournisseur :</span>
              </label>
              <input
                type="text"
                value={testBatch}
                onChange={(e) => setTestBatch(e.target.value)}
                className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
              />
            </div>

            <div>
              <label className="text-xs text-slate-400 block mb-1 flex items-center space-x-1">
                <User className="w-3.5 h-3.5 text-indigo-400" />
                <span>Opérateur Référent :</span>
              </label>
              <input
                type="text"
                value={operatorName}
                onChange={(e) => setOperatorName(e.target.value)}
                className="w-full bg-slate-900 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
              />
            </div>
          </div>

          {/* Saisie des Variables d'Entrée */}
          <div>
            <h4 className="text-xs font-bold uppercase tracking-wider text-slate-300 mb-3 flex items-center justify-between">
              <span>Saisie des Mesures Expérimentales ({protocol.extracted_inputs.length} variables)</span>
              <span className="text-[11px] text-slate-400 font-normal">
                Conditions : {protocol.metadata.conditions_nominales?.temperature || '23°C'} • {protocol.metadata.conditions_nominales?.hygrometrie || '50% HR'}
              </span>
            </h4>

            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3.5">
              {protocol.extracted_inputs.map((inp) => (
                <div
                  key={inp.id}
                  className="bg-slate-950 p-3.5 rounded-xl border border-slate-800"
                >
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="text-xs font-semibold text-slate-200">
                      {inp.label} ({inp.symbol || inp.key})
                    </span>
                    <span className="text-[11px] font-bold text-cyan-300 font-mono">
                      {inp.unit}
                    </span>
                  </div>
                  <input
                    type="number"
                    step="any"
                    value={inputValues[inp.key] !== undefined ? inputValues[inp.key] : ''}
                    onChange={(e) =>
                      setInputValues({
                        ...inputValues,
                        [inp.key]: parseFloat(e.target.value) || 0,
                      })
                    }
                    className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm font-mono text-white focus:outline-none focus:border-blue-500"
                  />
                </div>
              ))}
            </div>
          </div>

          {/* Compute Button */}
          <div className="flex justify-center">
            <button
              onClick={handleCompute}
              className="px-6 py-3 rounded-2xl text-sm font-bold bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-500 hover:to-teal-500 text-white shadow-lg shadow-emerald-600/30 transition flex items-center space-x-2"
            >
              <Play className="w-4 h-4 fill-current" />
              <span>Calculer les Résultats de l Essai</span>
            </button>
          </div>

          {/* Results Certificate Section */}
          {isTestRun && (
            <div className="bg-slate-950 border-2 border-emerald-500/40 rounded-2xl p-5 space-y-4">
              <div className="flex items-center justify-between pb-3 border-b border-slate-800">
                <div className="flex items-center space-x-2 text-emerald-400">
                  <CheckCircle2 className="w-5 h-5" />
                  <h4 className="text-sm font-bold text-white">
                    Rapport de Résultats d Essai — {sampleId}
                  </h4>
                </div>

                <button
                  onClick={handlePrintCertificate}
                  className="px-3 py-1.5 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition flex items-center space-x-1.5"
                >
                  <Printer className="w-3.5 h-3.5" />
                  <span>Imprimer le Rapport</span>
                </button>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-3.5">
                {protocol.extracted_formulas.map((form) => {
                  const val = outputs[form.output_key];
                  const err = calcErrors[form.output_key];

                  return (
                    <div
                      key={form.id}
                      className="p-4 rounded-xl bg-slate-900 border border-slate-800"
                    >
                      <div className="text-xs text-slate-400 font-semibold mb-1">
                        {form.label} ({form.symbol || form.output_key})
                      </div>
                      {err ? (
                        <div className="text-xs text-rose-400">{err}</div>
                      ) : (
                        <div className="flex items-baseline space-x-1.5 mt-1">
                          <span className="text-2xl font-bold font-mono text-emerald-400">
                            {val !== undefined ? val.toFixed(form.decimals ?? 2) : '—'}
                          </span>
                          <span className="text-xs font-semibold text-slate-400">{form.unit}</span>
                        </div>
                      )}
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-slate-800 bg-slate-850 flex items-center justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-white transition"
          >
            Fermer
          </button>
        </div>
      </div>
    </div>
  );
};
