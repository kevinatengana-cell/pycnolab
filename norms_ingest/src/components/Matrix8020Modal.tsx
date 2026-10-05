import React, { useState } from 'react';
import { 
  TableProperties, 
  X, 
  Bot, 
  UserCheck, 
  Clock, 
  TrendingUp, 
  CheckCircle2, 
  Sliders,
  ShieldAlert
} from 'lucide-react';

interface Matrix8020ModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const Matrix8020Modal: React.FC<Matrix8020ModalProps> = ({ isOpen, onClose }) => {
  const [protocolsPerMonth, setProtocolsPerMonth] = useState(25);

  if (!isOpen) return null;

  const manualMinutes = protocolsPerMonth * 15;
  const assistedMinutes = protocolsPerMonth * 0.75; // 45 seconds = 0.75 min
  const savedMinutes = manualMinutes - assistedMinutes;
  const savedHours = (savedMinutes / 60).toFixed(1);
  const timeSavedPct = Math.round((savedMinutes / manualMinutes) * 100);

  const matrixRows = [
    {
      task: 'Code & Nom de Norme',
      machine: 'Extraction Regex automatique & titre officiel',
      machineDetail: 'pdfplumber + extraction d en-tête',
      human: 'Validation visuelle d un clic',
      humanDetail: 'Contrôle rapide du millésime et du domaine',
    },
    {
      task: 'Liste des Variables (Inputs)',
      machine: 'Extraction des tableaux du PDF & symboles',
      machineDetail: 'Reconnaissance des symboles (b, h, F, L0)',
      human: 'Ajout/Correction de variables spécifiques',
      humanDetail: 'Ajustement des bornes min/max et tolérances',
    },
    {
      task: 'Normalisation des Unités',
      machine: 'Saisie et conversion automatique (KN -> kN, N/mm² -> MPa)',
      machineDetail: 'Dictionnaire des unités physiques normalisées',
      human: 'Choix de l unité d affichage par défaut',
      humanDetail: 'Adaptation aux habitudes de laboratoire',
    },
    {
      task: 'Formules Complexes',
      machine: 'Pré-détection de la structure brute & équations',
      machineDetail: 'Capture des motifs d égalités (σ = F / A)',
      human: 'Assemblage final via le Pill Builder No-Code',
      humanDetail: 'Validation des parenthèses et des fractions',
    },
    {
      task: 'Contrôle Qualité & Conformité',
      machine: 'Vérification de syntaxe mathématique AST',
      machineDetail: 'Analyseur lexical sans risque de faille',
      human: 'Test de valeurs limites dans la Sandbox',
      humanDetail: 'Comparaison avec éprouvette étalon connue',
    },
  ];

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 sm:p-6 animate-in fade-in duration-200">
      <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-5xl overflow-hidden shadow-2xl">
        {/* Header */}
        <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-850">
          <div className="flex items-center space-x-3">
            <div className="w-8 h-8 rounded-lg bg-cyan-500/20 text-cyan-400 flex items-center justify-center">
              <TableProperties className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-lg font-bold text-white">
                Matrice de Répartition des Tâches (80% Machine vs 20% Humain)
              </h3>
              <p className="text-xs text-slate-400">
                La synergie parfaite : l automatisation industrielle assistée par l expertise du technicien
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

        {/* Content */}
        <div className="p-6 space-y-6 max-h-[75vh] overflow-y-auto">
          {/* Main Matrix Table */}
          <div className="overflow-x-auto rounded-xl border border-slate-800 shadow-sm">
            <table className="w-full text-left border-collapse text-xs">
              <thead>
                <tr className="bg-slate-950 border-b border-slate-800 text-slate-300">
                  <th className="py-3 px-4 font-bold uppercase tracking-wider text-[11px] w-1/4">
                    Tâche Métier
                  </th>
                  <th className="py-3 px-4 font-bold uppercase tracking-wider text-[11px] text-cyan-400 w-[38%]">
                    <div className="flex items-center space-x-1.5">
                      <Bot className="w-4 h-4" />
                      <span>Prise en charge Machine (80%)</span>
                    </div>
                  </th>
                  <th className="py-3 px-4 font-bold uppercase tracking-wider text-[11px] text-indigo-400 w-[37%]">
                    <div className="flex items-center space-x-1.5">
                      <UserCheck className="w-4 h-4" />
                      <span>Prise en charge Opérateur (20%)</span>
                    </div>
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60 bg-slate-900/60">
                {matrixRows.map((row, idx) => (
                  <tr key={idx} className="hover:bg-slate-800/40 transition-colors">
                    <td className="py-3.5 px-4 font-semibold text-white">
                      {row.task}
                    </td>
                    <td className="py-3.5 px-4 text-slate-300">
                      <div className="font-medium text-cyan-200 mb-0.5">{row.machine}</div>
                      <div className="text-[11px] text-slate-400">{row.machineDetail}</div>
                    </td>
                    <td className="py-3.5 px-4 text-slate-300">
                      <div className="font-medium text-indigo-200 mb-0.5">{row.human}</div>
                      <div className="text-[11px] text-slate-400">{row.humanDetail}</div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Time Savings Interactive Simulator */}
          <div className="bg-gradient-to-br from-slate-950 to-slate-900 p-5 rounded-xl border border-slate-800">
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-4">
              <div>
                <h4 className="text-sm font-bold text-white flex items-center space-x-2">
                  <TrendingUp className="w-4 h-4 text-emerald-400" />
                  <span>Calculateur de Gain de Productivité Laboratoire</span>
                </h4>
                <p className="text-xs text-slate-400 mt-0.5">
                  Mesurez le temps économisé en remplaçant la saisie manuelle intégrale par l approche mixte.
                </p>
              </div>

              <div className="flex items-center space-x-3 bg-slate-850 px-3 py-1.5 rounded-lg border border-slate-700">
                <Sliders className="w-3.5 h-3.5 text-slate-400" />
                <span className="text-xs text-slate-300">Volume :</span>
                <input
                  type="range"
                  min="5"
                  max="100"
                  step="5"
                  value={protocolsPerMonth}
                  onChange={(e) => setProtocolsPerMonth(Number(e.target.value))}
                  className="w-24 accent-blue-500 cursor-pointer"
                />
                <span className="text-xs font-bold text-white min-w-[3rem]">
                  {protocolsPerMonth} normes/mois
                </span>
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div className="p-3.5 rounded-lg bg-slate-900 border border-slate-800 flex items-center justify-between">
                <div>
                  <div className="text-[11px] text-slate-400">Temps Saisie Manuelle (100%)</div>
                  <div className="text-lg font-bold text-rose-400 mt-0.5 font-mono">
                    {(manualMinutes / 60).toFixed(1)} h
                  </div>
                  <div className="text-[10px] text-slate-500">15 minutes par protocole</div>
                </div>
                <Clock className="w-7 h-7 text-rose-500/30" />
              </div>

              <div className="p-3.5 rounded-lg bg-slate-900 border border-slate-800 flex items-center justify-between">
                <div>
                  <div className="text-[11px] text-slate-400">Temps Approche Mixte (80/20)</div>
                  <div className="text-lg font-bold text-cyan-400 mt-0.5 font-mono">
                    {(assistedMinutes / 60).toFixed(1)} h
                  </div>
                  <div className="text-[10px] text-slate-500">&lt; 45 secondes par protocole</div>
                </div>
                <Bot className="w-7 h-7 text-cyan-500/30" />
              </div>

              <div className="p-3.5 rounded-lg bg-emerald-950/40 border border-emerald-800/50 flex items-center justify-between">
                <div>
                  <div className="text-[11px] text-emerald-300 font-semibold">Temps Économisé Net</div>
                  <div className="text-lg font-bold text-emerald-400 mt-0.5 font-mono">
                    + {savedHours} heures
                  </div>
                  <div className="text-[10px] text-emerald-300/80">-{timeSavedPct}% de temps consacré</div>
                </div>
                <CheckCircle2 className="w-7 h-7 text-emerald-400" />
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="px-6 py-4 border-t border-slate-800 bg-slate-850 flex items-center justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 rounded-lg text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-white transition"
          >
            Fermer
          </button>
        </div>
      </div>
    </div>
  );
};
