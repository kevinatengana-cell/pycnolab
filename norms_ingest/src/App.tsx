/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect } from 'react';
import { NormDraft, StandardPreset } from './types';
import { INITIAL_PROTOCOLS, STANDARDS_PRESETS } from './data/standardsData';
import { Header } from './components/Header';
import { ProtocolsDashboard } from './components/ProtocolsDashboard';
import { EditeurProtocoleScreen } from './components/EditeurProtocoleScreen';
import { StandardsLibraryView } from './components/StandardsLibraryView';
import { ArchitectureDiagramModal } from './components/ArchitectureDiagramModal';
import { Matrix8020Modal } from './components/Matrix8020Modal';
import { NewIngestionModal } from './components/NewIngestionModal';
import { JsonViewerModal } from './components/JsonViewerModal';
import { LiveTestExecutionModal } from './components/LiveTestExecutionModal';

export default function App() {
  const [protocols, setProtocols] = useState<NormDraft[]>(() => {
    try {
      const saved = localStorage.getItem('pycnolab_protocols_v1');
      if (saved) {
        return JSON.parse(saved);
      }
    } catch {
      // ignore
    }
    return INITIAL_PROTOCOLS;
  });

  const [activeTab, setActiveTab] = useState<'dashboard' | 'editor' | 'library'>('dashboard');
  const [selectedDraft, setSelectedDraft] = useState<NormDraft | null>(null);

  // Modals state
  const [isDiagramOpen, setIsDiagramOpen] = useState(false);
  const [isMatrixOpen, setIsMatrixOpen] = useState(false);
  const [isNewIngestionOpen, setIsNewIngestionOpen] = useState(false);
  const [isJsonViewerOpen, setIsJsonViewerOpen] = useState(false);
  const [inspectingDraft, setInspectingDraft] = useState<NormDraft | null>(null);
  const [isLiveTestOpen, setIsLiveTestOpen] = useState(false);
  const [testingProtocol, setTestingProtocol] = useState<NormDraft | null>(null);

  // Toast Notification state
  const [toastMessage, setToastMessage] = useState<{ text: string; type: 'success' | 'info' | 'error' } | null>(null);

  const showToast = (text: string, type: 'success' | 'info' | 'error' = 'success') => {
    setToastMessage({ text, type });
    setTimeout(() => setToastMessage(null), 3500);
  };

  // Sync protocols to localStorage
  useEffect(() => {
    try {
      localStorage.setItem('pycnolab_protocols_v1', JSON.stringify(protocols));
    } catch {
      // ignore
    }
  }, [protocols]);

  // Open Editor for a specific protocol draft
  const handleOpenEditor = (draft: NormDraft) => {
    setSelectedDraft(draft);
    setActiveTab('editor');
  };

  // Handle Updates to the currently edited draft
  const handleUpdateDraft = (updated: NormDraft) => {
    setSelectedDraft(updated);
    setProtocols((prev) =>
      prev.map((p) => (p.draft_id === updated.draft_id ? updated : p))
    );
  };

  // Handle Protocol Deployment
  const handleDeployProtocol = (deployed: NormDraft) => {
    setProtocols((prev) => {
      const exists = prev.some((p) => p.draft_id === deployed.draft_id);
      if (exists) {
        return prev.map((p) => (p.draft_id === deployed.draft_id ? deployed : p));
      }
      return [deployed, ...prev];
    });
    setSelectedDraft(deployed);
    showToast(`Protocole ${deployed.metadata.norme} déployé avec succès en Base de Données (Statut ACTIVE) !`, 'success');
  };

  // Handle Ingestion Success from Modal
  const handleIngestSuccess = (newDraft: NormDraft) => {
    setProtocols((prev) => [newDraft, ...prev]);
    setIsNewIngestionOpen(false);
    setSelectedDraft(newDraft);
    setActiveTab('editor');
    showToast(`Norme ${newDraft.metadata.norme} ingérée avec succès (~80% pré-remplie). Ouverture de l'éditeur...`, 'success');
  };

  // Ingest preset from library
  const handleSelectPresetFromLibrary = (preset: StandardPreset) => {
    const newDraft: NormDraft = {
      ...preset.draft,
      draft_id: `draft_${preset.code.toLowerCase().replace(/[^a-z0-9]/g, '_')}_${Date.now()}`,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };
    setProtocols((prev) => [newDraft, ...prev]);
    setSelectedDraft(newDraft);
    setActiveTab('editor');
    showToast(`Modèle ${preset.code} chargé dans l'Éditeur No-Code.`, 'info');
  };

  // Delete Protocol
  const handleDeleteProtocol = (draftId: string) => {
    if (window.confirm('Voulez-vous vraiment supprimer ce protocole ?')) {
      setProtocols((prev) => prev.filter((p) => p.draft_id !== draftId));
      if (selectedDraft?.draft_id === draftId) {
        setSelectedDraft(null);
        setActiveTab('dashboard');
      }
      showToast('Protocole supprimé.', 'info');
    }
  };

  // Run Test modal
  const handleRunTest = (protocol: NormDraft) => {
    setTestingProtocol(protocol);
    setIsLiveTestOpen(true);
  };

  // Inspect JSON
  const handleOpenJsonInspector = (draft: NormDraft) => {
    setInspectingDraft(draft);
    setIsJsonViewerOpen(true);
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans selection:bg-blue-600 selection:text-white">
      {/* App Header */}
      <Header
        activeTab={activeTab}
        onSelectTab={(tab) => {
          if (tab === 'editor' && !selectedDraft && protocols.length > 0) {
            setSelectedDraft(protocols[0]);
          }
          setActiveTab(tab);
        }}
        onOpenNewIngestion={() => setIsNewIngestionOpen(true)}
        onOpenDiagram={() => setIsDiagramOpen(true)}
        onOpenMatrix={() => setIsMatrixOpen(true)}
      />

      {/* Main View Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Toast Notification */}
        {toastMessage && (
          <div className="fixed top-20 right-6 z-50 animate-in fade-in slide-in-from-top-4 duration-300">
            <div
              className={`px-4 py-3 rounded-2xl text-xs font-semibold shadow-2xl border flex items-center space-x-2 ${
                toastMessage.type === 'success'
                  ? 'bg-emerald-950 text-emerald-200 border-emerald-500/60 shadow-emerald-950/50'
                  : toastMessage.type === 'error'
                  ? 'bg-rose-950 text-rose-200 border-rose-500/60 shadow-rose-950/50'
                  : 'bg-blue-950 text-blue-200 border-blue-500/60 shadow-blue-950/50'
              }`}
            >
              <span>{toastMessage.text}</span>
            </div>
          </div>
        )}

        {/* Dynamic Views */}
        {activeTab === 'dashboard' && (
          <ProtocolsDashboard
            protocols={protocols}
            onOpenEditor={handleOpenEditor}
            onOpenNewIngestion={() => setIsNewIngestionOpen(true)}
            onRunTest={handleRunTest}
            onDeleteProtocol={handleDeleteProtocol}
            onOpenJsonInspector={handleOpenJsonInspector}
            onOpenMatrix={() => setIsMatrixOpen(true)}
            onOpenDiagram={() => setIsDiagramOpen(true)}
          />
        )}

        {activeTab === 'editor' && selectedDraft && (
          <EditeurProtocoleScreen
            draft={selectedDraft}
            onUpdateDraft={handleUpdateDraft}
            onDeployProtocol={handleDeployProtocol}
            onBackToDashboard={() => setActiveTab('dashboard')}
            onOpenJsonInspector={() => handleOpenJsonInspector(selectedDraft)}
          />
        )}

        {activeTab === 'editor' && !selectedDraft && (
          <div className="text-center py-20 bg-slate-900/60 rounded-3xl border border-slate-800 p-8">
            <h3 className="text-base font-bold text-white mb-2">Aucun protocole sélectionné</h3>
            <p className="text-xs text-slate-400 mb-4">
              Veuillez sélectionner un protocole depuis le catalogue ou démarrer une nouvelle ingestion.
            </p>
            <button
              onClick={() => setIsNewIngestionOpen(true)}
              className="px-4 py-2 rounded-xl text-xs font-semibold bg-blue-600 hover:bg-blue-500 text-white transition"
            >
              + Ingérer une Norme
            </button>
          </div>
        )}

        {activeTab === 'library' && (
          <StandardsLibraryView onSelectStandard={handleSelectPresetFromLibrary} />
        )}
      </main>

      {/* Modals */}
      <ArchitectureDiagramModal
        isOpen={isDiagramOpen}
        onClose={() => setIsDiagramOpen(false)}
      />

      <Matrix8020Modal
        isOpen={isMatrixOpen}
        onClose={() => setIsMatrixOpen(false)}
      />

      <NewIngestionModal
        isOpen={isNewIngestionOpen}
        onClose={() => setIsNewIngestionOpen(false)}
        onIngestSuccess={handleIngestSuccess}
      />

      <JsonViewerModal
        isOpen={isJsonViewerOpen}
        onClose={() => setIsJsonViewerOpen(false)}
        draft={inspectingDraft || selectedDraft || protocols[0]}
        onUpdateDraft={(updated) => {
          handleUpdateDraft(updated);
          showToast('JSON intermédiaire mis à jour avec succès.', 'info');
        }}
      />

      <LiveTestExecutionModal
        isOpen={isLiveTestOpen}
        onClose={() => setIsLiveTestOpen(false)}
        protocol={testingProtocol}
      />
    </div>
  );
}
