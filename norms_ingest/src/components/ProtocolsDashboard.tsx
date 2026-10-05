import React, { useState } from 'react';
import { NormDraft } from '../types';
import { 
  Search, 
  Filter, 
  FlaskConical, 
  Edit3, 
  CheckCircle2, 
  Clock, 
  Trash2, 
  Play, 
  Braces, 
  FileDown, 
  Plus, 
  Sparkles, 
  Cpu, 
  ShieldCheck,
  ChevronRight,
  TrendingUp,
  Layers
} from 'lucide-react';

interface ProtocolsDashboardProps {
  protocols: NormDraft[];
  onOpenEditor: (protocol: NormDraft) => void;
  onOpenNewIngestion: () => void;
  onRunTest: (protocol: NormDraft) => void;
  onDeleteProtocol: (draftId: string) => void;
  onOpenJsonInspector: (protocol: NormDraft) => void;
  onOpenMatrix: () => void;
  onOpenDiagram: () => void;
}

export const ProtocolsDashboard: React.FC<ProtocolsDashboardProps> = ({
  protocols,
  onOpenEditor,
  onOpenNewIngestion,
  onRunTest,
  onDeleteProtocol,
  onOpenJsonInspector,
  onOpenMatrix,
  onOpenDiagram,
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedDomain, setSelectedDomain] = useState<string>('all');

  const domains = Array.from(new Set(protocols.map((p) => p.metadata.domaine).filter(Boolean)));

  const filteredProtocols = protocols.filter((p) => {
    const matchesSearch =
      p.metadata.norme.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.metadata.titre.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (p.metadata.domaine && p.metadata.domaine.toLowerCase().includes(searchQuery.toLowerCase()));

    const matchesDomain = selectedDomain === 'all' || p.metadata.domaine === selectedDomain;

    return matchesSearch && matchesDomain;
  });

  const activeProtocolsCount = protocols.filter((p) => p.status === 'ACTIVE').length;
  const draftProtocolsCount = protocols.filter((p) => p.status !== 'ACTIVE').length;

  return (
    <div className="space-y-8 animate-in fade-in duration-200">
      {/* Hero Welcome Banner */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-slate-900 via-blue-950/80 to-slate-900 border border-slate-800 p-6 sm:p-8 shadow-xl">
        <div className="relative z-10 flex flex-col lg:flex-row lg:items-center justify-between gap-6">
          <div className="max-w-2xl space-y-2">
            <div className="inline-flex items-center space-x-2 px-3 py-1 rounded-full bg-blue-900/60 border border-blue-700/50 text-blue-300 text-xs font-semibold">
              <ShieldCheck className="w-3.5 h-3.5 text-cyan-400" />
              <span>Garantie Zéro Erreur • Approche Mixte 80/20</span>
            </div>
            <h1 className="text-2xl sm:text-3xl font-extrabold text-white tracking-tight">
              Ingestion & Éditeur No-Code des Normes d Essais
            </h1>
            <p className="text-sm text-slate-300 leading-relaxed">
              Extraction automatique des symboles et formules mathématiques par script Python / IA (~80%) couplée à la validation assistée du technicien de laboratoire (20%).
            </p>
          </div>

          {/* Quick Metrics Badges */}
          <div className="flex flex-wrap items-center gap-3">
            <button
              onClick={onOpenMatrix}
              className="px-4 py-3 rounded-2xl bg-slate-850/80 border border-slate-700/80 hover:border-cyan-500/60 text-left transition shadow-md group"
            >
              <div className="flex items-center space-x-2 text-cyan-400 text-xs font-bold">
                <Cpu className="w-4 h-4" />
                <span>Gain de Temps</span>
              </div>
              <div className="text-lg font-bold text-white mt-0.5">15 min ➔ 45 sec</div>
              <div className="text-[10px] text-slate-400 group-hover:text-cyan-300 transition">
                Voir la Matrice 80/20 →
              </div>
            </button>

            <button
              onClick={onOpenDiagram}
              className="px-4 py-3 rounded-2xl bg-slate-850/80 border border-slate-700/80 hover:border-indigo-500/60 text-left transition shadow-md group"
            >
              <div className="flex items-center space-x-2 text-indigo-400 text-xs font-bold">
                <Layers className="w-4 h-4" />
                <span>Fiabilité</span>
              </div>
              <div className="text-lg font-bold text-white mt-0.5">100 % Précision</div>
              <div className="text-[10px] text-slate-400 group-hover:text-indigo-300 transition">
                Voir l Architecture →
              </div>
            </button>
          </div>
        </div>
      </div>

      {/* Filter & Search Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex flex-1 items-center space-x-3 max-w-md">
          <div className="relative w-full">
            <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Rechercher une norme (ex: ISO 527, EN 196, traction...)"
              className="w-full bg-slate-900 border border-slate-800 rounded-xl pl-9 pr-4 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-blue-500"
            />
          </div>
        </div>

        <div className="flex items-center space-x-3">
          {/* Domain Filter */}
          <div className="flex items-center space-x-2">
            <Filter className="w-4 h-4 text-slate-400" />
            <select
              value={selectedDomain}
              onChange={(e) => setSelectedDomain(e.target.value)}
              className="bg-slate-900 border border-slate-800 text-xs rounded-xl px-3 py-2 text-slate-300 focus:outline-none focus:border-blue-500 font-medium"
            >
              <option value="all">Tous les Domaines ({protocols.length})</option>
              {domains.map((d) => (
                <option key={d} value={d}>
                  {d}
                </option>
              ))}
            </select>
          </div>

          <button
            onClick={onOpenNewIngestion}
            className="px-4 py-2.5 rounded-xl text-xs font-semibold bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white shadow-md shadow-blue-600/30 transition flex items-center space-x-1.5"
          >
            <Plus className="w-4 h-4" />
            <span>+ Ingérer une Norme</span>
          </button>
        </div>
      </div>

      {/* Protocols Grid */}
      {filteredProtocols.length === 0 ? (
        <div className="text-center py-16 bg-slate-900/40 rounded-3xl border border-slate-800 p-8">
          <FlaskConical className="w-12 h-12 text-slate-600 mx-auto mb-3" />
          <h3 className="text-base font-bold text-white">Aucun protocole trouvé</h3>
          <p className="text-xs text-slate-400 max-w-sm mx-auto mt-1 mb-4">
            Aucune norme ne correspond à vos filtres actuels. Lancez une nouvelle ingestion assistée pour démarrer.
          </p>
          <button
            onClick={onOpenNewIngestion}
            className="px-4 py-2 rounded-xl text-xs font-semibold bg-blue-600 text-white"
          >
            Ingérer un PDF de Norme
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
          {filteredProtocols.map((p) => {
            const isActive = p.status === 'ACTIVE';
            const confidencePct = Math.round(p.metadata.confidence * 100);

            return (
              <div
                key={p.draft_id}
                className="bg-slate-900 border border-slate-800 hover:border-slate-700 rounded-2xl p-5 flex flex-col justify-between shadow-md transition-all group"
              >
                <div>
                  {/* Top Bar */}
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center space-x-2">
                      <span className="px-2.5 py-0.5 text-xs font-bold font-mono rounded-md bg-blue-950 text-blue-300 border border-blue-800/60">
                        {p.metadata.norme}
                      </span>
                      <span className="text-[11px] text-slate-400 font-medium">
                        {p.metadata.organisme}
                      </span>
                    </div>

                    <span
                      className={`px-2 py-0.5 text-[10px] font-bold rounded-full border ${
                        isActive
                          ? 'bg-emerald-950/80 text-emerald-300 border-emerald-700/60'
                          : 'bg-amber-950/80 text-amber-300 border-amber-700/60'
                      }`}
                    >
                      {isActive ? '● ACTIVE' : '● BROUILLON'}
                    </span>
                  </div>

                  {/* Title & Domain */}
                  <h4 className="text-sm font-bold text-white mb-1.5 line-clamp-2 leading-snug">
                    {p.metadata.titre}
                  </h4>
                  <div className="text-xs text-cyan-400 font-medium mb-3">
                    {p.metadata.domaine}
                  </div>

                  {/* Description preview */}
                  {p.metadata.description && (
                    <p className="text-xs text-slate-400 line-clamp-2 leading-relaxed mb-4">
                      {p.metadata.description}
                    </p>
                  )}

                  {/* Metrics Pills */}
                  <div className="grid grid-cols-3 gap-2 py-2.5 px-3 bg-slate-950 rounded-xl border border-slate-800/80 text-center mb-4">
                    <div>
                      <div className="text-[10px] text-slate-400">Inputs</div>
                      <div className="text-xs font-bold text-white font-mono mt-0.5">
                        {p.extracted_inputs.length}
                      </div>
                    </div>
                    <div>
                      <div className="text-[10px] text-slate-400">Formules</div>
                      <div className="text-xs font-bold text-indigo-300 font-mono mt-0.5">
                        {p.extracted_formulas.length}
                      </div>
                    </div>
                    <div>
                      <div className="text-[10px] text-slate-400">Confiance</div>
                      <div className="text-xs font-bold text-emerald-400 font-mono mt-0.5">
                        {confidencePct} %
                      </div>
                    </div>
                  </div>
                </div>

                {/* Card Action Buttons */}
                <div className="pt-3 border-t border-slate-800/80 flex items-center justify-between">
                  <div className="flex items-center space-x-1.5">
                    <button
                      onClick={() => onOpenJsonInspector(p)}
                      className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition"
                      title="Inspecter le JSON Intermédiaire"
                    >
                      <Braces className="w-4 h-4 text-cyan-400" />
                    </button>

                    <button
                      onClick={() => onDeleteProtocol(p.draft_id)}
                      className="p-1.5 rounded-lg text-slate-400 hover:text-rose-400 hover:bg-slate-800 transition"
                      title="Supprimer ce protocole"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>

                  <div className="flex items-center space-x-2">
                    <button
                      onClick={() => onOpenEditor(p)}
                      className="px-3 py-1.5 rounded-xl text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition flex items-center space-x-1"
                    >
                      <Edit3 className="w-3.5 h-3.5 text-blue-400" />
                      <span>Éditer No-Code</span>
                    </button>

                    <button
                      onClick={() => onRunTest(p)}
                      className="px-3 py-1.5 rounded-xl text-xs font-semibold bg-blue-600 hover:bg-blue-500 text-white shadow-sm transition flex items-center space-x-1"
                      title="Exécuter un essai laboratoire avec ce protocole"
                    >
                      <Play className="w-3.5 h-3.5 fill-current" />
                      <span>Tester</span>
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
