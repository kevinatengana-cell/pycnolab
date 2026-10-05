import React from 'react';
import { 
  FlaskConical, 
  Cpu, 
  UserCheck, 
  FileCode2, 
  Sparkles, 
  HelpCircle, 
  Upload, 
  Layers,
  CheckCircle2,
  TableProperties
} from 'lucide-react';

interface HeaderProps {
  activeTab: 'dashboard' | 'editor' | 'library' | 'matrix';
  setActiveTab: (tab: 'dashboard' | 'editor' | 'library' | 'matrix') => void;
  onOpenNewIngestion: () => void;
  onOpenDiagram: () => void;
  onOpenMatrix: () => void;
  activeCount: number;
  draftCount: number;
}

export const Header: React.FC<HeaderProps> = ({
  activeTab,
  setActiveTab,
  onOpenNewIngestion,
  onOpenDiagram,
  onOpenMatrix,
  activeCount,
  draftCount,
}) => {
  return (
    <header className="bg-slate-900 border-b border-slate-800 text-white sticky top-0 z-40 shadow-lg">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Brand & Logo */}
          <div className="flex items-center space-x-3 cursor-pointer" onClick={() => setActiveTab('dashboard')}>
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-blue-600 via-indigo-600 to-cyan-400 flex items-center justify-center shadow-md shadow-blue-500/20">
              <FlaskConical className="w-5 h-5 text-white" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <span className="font-bold text-lg tracking-tight bg-clip-text text-transparent bg-gradient-to-r from-white via-slate-100 to-blue-200">
                  PycnoLab
                </span>
                <span className="px-2 py-0.5 text-xs font-semibold rounded-full bg-blue-900/80 text-blue-300 border border-blue-700/50">
                  Approche Mixte 80/20
                </span>
              </div>
              <p className="text-xs text-slate-400 font-medium hidden sm:block">
                Ingestion Automatisée & Éditeur No-Code de Protocoles d Essais
              </p>
            </div>
          </div>

          {/* Navigation Links */}
          <nav className="hidden md:flex items-center space-x-1">
            <button
              id="nav-dashboard-btn"
              onClick={() => setActiveTab('dashboard')}
              className={`px-3 py-2 rounded-lg text-xs font-semibold transition-all flex items-center space-x-1.5 ${
                activeTab === 'dashboard'
                  ? 'bg-blue-600/30 text-blue-300 border border-blue-500/40 shadow-sm'
                  : 'text-slate-300 hover:text-white hover:bg-slate-800/60'
              }`}
            >
              <Layers className="w-4 h-4" />
              <span>Tableau de Bord</span>
            </button>

            <button
              id="nav-library-btn"
              onClick={() => setActiveTab('library')}
              className={`px-3 py-2 rounded-lg text-xs font-semibold transition-all flex items-center space-x-1.5 ${
                activeTab === 'library'
                  ? 'bg-blue-600/30 text-blue-300 border border-blue-500/40 shadow-sm'
                  : 'text-slate-300 hover:text-white hover:bg-slate-800/60'
              }`}
            >
              <FileCode2 className="w-4 h-4" />
              <span>Catalogue des Normes</span>
            </button>

            <button
              id="nav-matrix-btn"
              onClick={onOpenMatrix}
              className="px-3 py-2 rounded-lg text-xs font-semibold text-slate-300 hover:text-white hover:bg-slate-800/60 transition-all flex items-center space-x-1.5"
            >
              <TableProperties className="w-4 h-4 text-cyan-400" />
              <span>Matrice 80/20</span>
            </button>

            <button
              id="nav-diagram-btn"
              onClick={onOpenDiagram}
              className="px-3 py-2 rounded-lg text-xs font-semibold text-slate-300 hover:text-white hover:bg-slate-800/60 transition-all flex items-center space-x-1.5"
            >
              <HelpCircle className="w-4 h-4 text-indigo-400" />
              <span>Workflow & Guide</span>
            </button>
          </nav>

          {/* Quick Metrics & CTA */}
          <div className="flex items-center space-x-3">
            <div className="hidden lg:flex items-center space-x-3 text-xs bg-slate-800/80 px-3 py-1.5 rounded-lg border border-slate-700/60">
              <div className="flex items-center space-x-1 text-emerald-400">
                <CheckCircle2 className="w-3.5 h-3.5" />
                <span className="font-semibold">{activeCount}</span>
                <span className="text-slate-400">Actifs</span>
              </div>
              <div className="h-3 w-px bg-slate-700" />
              <div className="flex items-center space-x-1 text-amber-400">
                <Cpu className="w-3.5 h-3.5" />
                <span className="font-semibold">{draftCount}</span>
                <span className="text-slate-400">Brouillons</span>
              </div>
            </div>

            <button
              id="header-new-ingest-btn"
              onClick={onOpenNewIngestion}
              className="px-3.5 py-2 rounded-lg text-xs font-semibold bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white shadow-md shadow-blue-600/30 transition-all transform hover:-translate-y-0.5 flex items-center space-x-1.5"
            >
              <Upload className="w-4 h-4" />
              <span>+ Ingestion PDF / Norme</span>
            </button>
          </div>
        </div>
      </div>
    </header>
  );
};
