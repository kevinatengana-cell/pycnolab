import React from 'react';
import { STANDARDS_PRESETS } from '../data/standardsData';
import { StandardPreset, NormDraft } from '../types';
import { 
  FileCode2, 
  Sparkles, 
  ArrowRight, 
  Cpu, 
  CheckCircle2, 
  Layers, 
  Building2, 
  Flame, 
  Box, 
  Mountain
} from 'lucide-react';

interface StandardsLibraryViewProps {
  onSelectStandard: (preset: StandardPreset) => void;
}

export const StandardsLibraryView: React.FC<StandardsLibraryViewProps> = ({
  onSelectStandard,
}) => {
  return (
    <div className="space-y-6 animate-in fade-in duration-200">
      {/* Header */}
      <div className="bg-slate-900 border border-slate-800 rounded-3xl p-6 sm:p-8">
        <div className="flex items-center space-x-3 mb-2">
          <div className="w-10 h-10 rounded-2xl bg-indigo-500/20 text-indigo-400 flex items-center justify-center">
            <FileCode2 className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-xl font-bold text-white">Catalogue & Référentiel des Normes Officielles</h2>
            <p className="text-xs text-slate-400">
              Modèles certifiés d essais mécaniques, thermiques et physiques prêts pour l ingestion assistée PycnoLab.
            </p>
          </div>
        </div>
      </div>

      {/* Norm Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
        {STANDARDS_PRESETS.map((preset) => {
          return (
            <div
              key={preset.code}
              className="bg-slate-900 border border-slate-800 hover:border-slate-700 rounded-2xl p-6 flex flex-col justify-between shadow-lg transition-all"
            >
              <div>
                <div className="flex items-center justify-between mb-3">
                  <div className="flex items-center space-x-2">
                    <span className="px-3 py-1 text-xs font-bold font-mono rounded-lg bg-blue-950 text-cyan-300 border border-blue-800/60">
                      {preset.code}
                    </span>
                    <span className="text-xs font-semibold text-slate-400">
                      {preset.organization}
                    </span>
                  </div>
                  <span className="text-xs text-slate-400 font-medium">{preset.domain}</span>
                </div>

                <h3 className="text-base font-bold text-white mb-2">{preset.title}</h3>
                <p className="text-xs text-slate-300 leading-relaxed mb-4">
                  {preset.description}
                </p>

                {/* Sample Formula Snippet */}
                <div className="p-3 bg-slate-950 rounded-xl border border-slate-800/80 mb-4 font-mono text-[11px] text-slate-400 space-y-1">
                  <div className="text-[10px] text-slate-500 font-bold uppercase tracking-wider">
                    Formules Détectées :
                  </div>
                  {preset.draft.extracted_formulas.map((f) => (
                    <div key={f.output_key} className="flex items-center justify-between text-slate-300">
                      <span>{f.symbol || f.output_key} = {f.raw_detected_formula}</span>
                      <span className="text-cyan-400 font-bold">[{f.unit}]</span>
                    </div>
                  ))}
                </div>
              </div>

              <div className="pt-4 border-t border-slate-800 flex items-center justify-between">
                <div className="text-xs text-slate-400">
                  {preset.draft.extracted_inputs.length} inputs • {preset.draft.extracted_formulas.length} formules
                </div>

                <button
                  onClick={() => onSelectStandard(preset)}
                  className="px-4 py-2 rounded-xl text-xs font-semibold bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white shadow-md shadow-blue-600/20 transition flex items-center space-x-1.5"
                >
                  <Sparkles className="w-3.5 h-3.5" />
                  <span>Ingérer ce Modèle</span>
                  <ArrowRight className="w-3.5 h-3.5 ml-1" />
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};
