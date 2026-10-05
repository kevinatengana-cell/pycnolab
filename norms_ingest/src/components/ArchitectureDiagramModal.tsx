import React from 'react';
import { 
  FileText, 
  Terminal, 
  Braces, 
  Edit3, 
  UserCheck, 
  Database, 
  ArrowRight, 
  X, 
  CheckCircle2, 
  ShieldCheck, 
  Clock, 
  Zap, 
  Cpu
} from 'lucide-react';

interface ArchitectureDiagramModalProps {
  isOpen: boolean;
  onClose: () => void;
  onStartIngestion: () => void;
}

export const ArchitectureDiagramModal: React.FC<ArchitectureDiagramModalProps> = ({
  isOpen,
  onClose,
  onStartIngestion,
}) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 sm:p-6 animate-in fade-in duration-200">
      <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-5xl overflow-hidden shadow-2xl">
        {/* Modal Header */}
        <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-850">
          <div className="flex items-center space-x-3">
            <div className="w-8 h-8 rounded-lg bg-indigo-500/20 text-indigo-400 flex items-center justify-center">
              <Zap className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-white">
                Architecture de l Approche Mixte (Assistée)
              </h3>
              <p className="text-xs text-slate-400">
                PycnoLab — 80 % Extraction Automatique Machine + 20 % Édition No-Code Humaine
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

        {/* Workflow Diagram */}
        <div className="p-6 space-y-8 max-h-[80vh] overflow-y-auto">
          {/* Visual Step-by-Step Flow */}
          <div className="bg-slate-950/80 p-5 rounded-xl border border-slate-800">
            <h4 className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-4 flex items-center space-x-1.5">
              <span>Flux d Ingestion & Validation Déterministe</span>
            </h4>

            <div className="grid grid-cols-1 md:grid-cols-4 gap-3 relative">
              {/* Step 1 */}
              <div className="bg-slate-900 p-4 rounded-xl border border-blue-500/30 relative flex flex-col justify-between">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-[10px] font-bold uppercase tracking-wider text-blue-400 bg-blue-950/60 px-2 py-0.5 rounded border border-blue-800/40">
                    Étape 1
                  </span>
                  <FileText className="w-5 h-5 text-blue-400" />
                </div>
                <div>
                  <h5 className="text-sm font-bold text-white mb-1">Norme Brute (PDF)</h5>
                  <p className="text-xs text-slate-400 leading-relaxed">
                    Téléversement du document officiel (ISO 527, EN 196, ASTM...).
                  </p>
                </div>
                <div className="mt-4 pt-3 border-t border-slate-800/60 text-[11px] text-blue-300 font-mono flex items-center space-x-1">
                  <Terminal className="w-3 h-3" />
                  <span>norm_ingestion_service.py</span>
                </div>
              </div>

              {/* Step 2 */}
              <div className="bg-slate-900 p-4 rounded-xl border border-cyan-500/30 relative flex flex-col justify-between">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-[10px] font-bold uppercase tracking-wider text-cyan-400 bg-cyan-950/60 px-2 py-0.5 rounded border border-cyan-800/40">
                    Étape 2 (80%)
                  </span>
                  <Braces className="w-5 h-5 text-cyan-400" />
                </div>
                <div>
                  <h5 className="text-sm font-bold text-white mb-1">JSON Pré-rempli</h5>
                  <p className="text-xs text-slate-400 leading-relaxed">
                    Extraction des symboles, inputs et équations avec indices de confiance.
                  </p>
                </div>
                <div className="mt-4 pt-3 border-t border-slate-800/60 text-[11px] text-cyan-300 flex items-center space-x-1">
                  <Cpu className="w-3 h-3" />
                  <span>Statuts &apos;verified&apos; / &apos;review&apos;</span>
                </div>
              </div>

              {/* Step 3 */}
              <div className="bg-slate-900 p-4 rounded-xl border border-indigo-500/30 relative flex flex-col justify-between">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-[10px] font-bold uppercase tracking-wider text-indigo-400 bg-indigo-950/60 px-2 py-0.5 rounded border border-indigo-800/40">
                    Étape 3 (20%)
                  </span>
                  <Edit3 className="w-5 h-5 text-indigo-400" />
                </div>
                <div>
                  <h5 className="text-sm font-bold text-white mb-1">Éditeur No-Code</h5>
                  <p className="text-xs text-slate-400 leading-relaxed">
                    Pill Builder interactif, normalisation des unités et sandbox de test.
                  </p>
                </div>
                <div className="mt-4 pt-3 border-t border-slate-800/60 text-[11px] text-indigo-300 flex items-center space-x-1">
                  <UserCheck className="w-3 h-3" />
                  <span>Validation Opérateur</span>
                </div>
              </div>

              {/* Step 4 */}
              <div className="bg-slate-900 p-4 rounded-xl border border-emerald-500/30 relative flex flex-col justify-between">
                <div className="flex items-center justify-between mb-3">
                  <span className="text-[10px] font-bold uppercase tracking-wider text-emerald-400 bg-emerald-950/60 px-2 py-0.5 rounded border border-emerald-800/40">
                    Étape 4 (100%)
                  </span>
                  <Database className="w-5 h-5 text-emerald-400" />
                </div>
                <div>
                  <h5 className="text-sm font-bold text-white mb-1">Protocole ACTIVE</h5>
                  <p className="text-xs text-slate-400 leading-relaxed">
                    Enregistrement en BDD PycnoLab, prêt pour la saisie directe des essais.
                  </p>
                </div>
                <div className="mt-4 pt-3 border-t border-slate-800/60 text-[11px] text-emerald-300 flex items-center space-x-1">
                  <CheckCircle2 className="w-3 h-3" />
                  <span>Zéro Erreur Garanti</span>
                </div>
              </div>
            </div>
          </div>

          {/* Strategic Advantages Cards */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="p-4 rounded-xl bg-slate-800/40 border border-slate-700/60">
              <div className="w-9 h-9 rounded-lg bg-emerald-500/10 text-emerald-400 flex items-center justify-center mb-3">
                <ShieldCheck className="w-5 h-5" />
              </div>
              <h5 className="text-sm font-bold text-white mb-1.5">1. Fiabilité Absolue (Erreur 0)</h5>
              <p className="text-xs text-slate-400 leading-relaxed">
                L œil de l expert métier garantit qu aucune corruption de symbole Unicode ou erreur OCR ne termine dans un rapport d essai officiel.
              </p>
            </div>

            <div className="p-4 rounded-xl bg-slate-800/40 border border-slate-700/60">
              <div className="w-9 h-9 rounded-lg bg-blue-500/10 text-blue-400 flex items-center justify-center mb-3">
                <Clock className="w-5 h-5" />
              </div>
              <h5 className="text-sm font-bold text-white mb-1.5">2. Gain de Temps Énorme</h5>
              <p className="text-xs text-slate-400 leading-relaxed">
                L opérateur ne passe pas 15 minutes à créer un protocole de zéro ; il passe moins de 60 secondes à valider des champs pré-remplis.
              </p>
            </div>

            <div className="p-4 rounded-xl bg-slate-800/40 border border-slate-700/60">
              <div className="w-9 h-9 rounded-lg bg-indigo-500/10 text-indigo-400 flex items-center justify-center mb-3">
                <Zap className="w-5 h-5" />
              </div>
              <h5 className="text-sm font-bold text-white mb-1.5">3. Autonomie Totale</h5>
              <p className="text-xs text-slate-400 leading-relaxed">
                Le laboratoire n a pas besoin de faire appel à un développeur pour ajouter une nouvelle norme ou adapter un coefficient.
              </p>
            </div>
          </div>
        </div>

        {/* Modal Footer */}
        <div className="px-6 py-4 border-t border-slate-800 bg-slate-850 flex items-center justify-between">
          <span className="text-xs text-slate-400">
            Guide technique d ingestion assistée PycnoLab
          </span>
          <div className="flex items-center space-x-3">
            <button
              onClick={onClose}
              className="px-4 py-2 rounded-lg text-xs font-semibold text-slate-300 hover:text-white hover:bg-slate-800 transition"
            >
              Fermer
            </button>
            <button
              onClick={() => {
                onClose();
                onStartIngestion();
              }}
              className="px-4 py-2 rounded-lg text-xs font-semibold bg-blue-600 hover:bg-blue-500 text-white shadow-md shadow-blue-600/30 transition flex items-center space-x-1.5"
            >
              <span>Tester une Ingestion</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
