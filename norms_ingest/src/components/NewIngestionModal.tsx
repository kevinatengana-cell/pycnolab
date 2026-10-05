import React, { useState } from 'react';
import { NormDraft, StandardPreset } from '../types';
import { STANDARDS_PRESETS } from '../data/standardsData';
import { 
  Upload, 
  FileText, 
  Sparkles, 
  Terminal, 
  CheckCircle2, 
  AlertCircle, 
  X, 
  Cpu, 
  ArrowRight, 
  Bot, 
  Layers, 
  FileCheck
} from 'lucide-react';

interface NewIngestionModalProps {
  isOpen: boolean;
  onClose: () => void;
  onIngestSuccess: (draft: NormDraft) => void;
}

export const NewIngestionModal: React.FC<NewIngestionModalProps> = ({
  isOpen,
  onClose,
  onIngestSuccess,
}) => {
  const [activeMode, setActiveMode] = useState<'preset' | 'pdf' | 'text'>('preset');
  const [selectedPreset, setSelectedPreset] = useState<StandardPreset>(STANDARDS_PRESETS[0]);
  const [customText, setCustomText] = useState('');
  const [customCode, setCustomCode] = useState('');
  const [customDomain, setCustomDomain] = useState('Matériaux & Génie Civil');
  const [uploadedFileName, setUploadedFileName] = useState<string | null>(null);

  // Ingestion execution states
  const [isProcessing, setIsProcessing] = useState(false);
  const [progressStep, setProgressStep] = useState(0);
  const [pipelineLogs, setPipelineLogs] = useState<string[]>([]);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setUploadedFileName(file.name);
      setCustomCode(file.name.replace(/\.[^/.]+$/, '').toUpperCase());

      const reader = new FileReader();
      reader.onload = (event) => {
        const text = event.target?.result as string;
        if (text) {
          setCustomText(text);
        } else {
          // If binary PDF, supply placeholder representative content
          setCustomText(`NORME OFFICIELLE EXTRAITE (${file.name})\nAnalyse automatique des tables de symboles et formules mathématiques.`);
        }
      };
      reader.readAsText(file);
    }
  };

  const handleExecuteIngestion = async () => {
    setIsProcessing(true);
    setErrorMsg(null);
    setPipelineLogs([]);
    setProgressStep(1);

    const addLog = (msg: string) => setPipelineLogs((prev) => [...prev, msg]);

    try {
      addLog(`[STEP 1/4] Téléversement du document : ${uploadedFileName || selectedPreset?.code || 'Norme_Source.pdf'}`);
      await new Promise((r) => setTimeout(r, 400));

      addLog(`[STEP 2/4] Initialisation norm_ingestion_service.py (pdfplumber & AST regex engine)...`);
      setProgressStep(2);
      await new Promise((r) => setTimeout(r, 450));

      const payload = {
        rawText: activeMode === 'preset' ? selectedPreset.sampleText : customText || selectedPreset.sampleText,
        standardCode: activeMode === 'preset' ? selectedPreset.code : customCode || 'ISO_STANDARD',
        domain: activeMode === 'preset' ? selectedPreset.domain : customDomain,
        filename: uploadedFileName,
      };

      addLog(`[STEP 3/4] Détection des grandeurs d'entrées, unités physiques et formules de calcul...`);
      setProgressStep(3);

      const response = await fetch('/api/ingest-norm', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      const data = await response.json();

      if (!data.success || !data.draft) {
        throw new Error(data.error || 'Échec de l extraction automatique');
      }

      addLog(`[STEP 4/4] Génération du JSON de pré-remplissage (~80% confiance = ${Math.round(data.draft.metadata.confidence * 100)}%)`);
      setProgressStep(4);
      await new Promise((r) => setTimeout(r, 400));

      const finalDraft: NormDraft = {
        ...data.draft,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };

      setIsProcessing(false);
      onIngestSuccess(finalDraft);
    } catch (err: any) {
      console.error(err);
      setIsProcessing(false);
      setErrorMsg(err.message || 'Erreur lors du traitement du document');
    }
  };

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-black/75 backdrop-blur-sm flex items-center justify-center p-4 sm:p-6 animate-in fade-in duration-200">
      <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-4xl overflow-hidden shadow-2xl">
        {/* Header */}
        <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-850">
          <div className="flex items-center space-x-3">
            <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-blue-600 to-cyan-500 flex items-center justify-center text-white shadow-md shadow-blue-500/20">
              <Upload className="w-5 h-5" />
            </div>
            <div>
              <h3 className="text-base font-bold text-white">
                Ingestion Automatique de Norme d Essai
              </h3>
              <p className="text-xs text-slate-400">
                Étape 1 & 2 : Parsing déterministe (Python/IA) & Génération du JSON Intermédiaire
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            disabled={isProcessing}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition disabled:opacity-40"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Mode Selector Tabs */}
        <div className="px-6 pt-4 pb-0 bg-slate-900 flex space-x-2 border-b border-slate-800">
          {[
            { id: 'preset', label: '1. Bibliothèque de Normes Types', icon: FileCheck },
            { id: 'pdf', label: '2. Téléverser un PDF Officiel', icon: Upload },
            { id: 'text', label: '3. Coller le Texte de la Norme', icon: FileText },
          ].map(({ id, label, icon: Icon }) => (
            <button
              key={id}
              onClick={() => setActiveMode(id as any)}
              disabled={isProcessing}
              className={`px-4 py-2.5 rounded-t-xl text-xs font-semibold flex items-center space-x-2 transition border-b-2 ${
                activeMode === id
                  ? 'border-blue-500 text-blue-400 bg-slate-850'
                  : 'border-transparent text-slate-400 hover:text-slate-200'
              }`}
            >
              <Icon className="w-4 h-4" />
              <span>{label}</span>
            </button>
          ))}
        </div>

        {/* Content Body */}
        <div className="p-6 space-y-6 max-h-[70vh] overflow-y-auto">
          {/* Preset Norms Mode */}
          {activeMode === 'preset' && (
            <div className="space-y-4">
              <span className="text-xs font-bold text-slate-300 uppercase tracking-wider block">
                Sélectionnez une norme officielle pré-configurée pour le test :
              </span>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3.5">
                {STANDARDS_PRESETS.map((preset) => (
                  <div
                    key={preset.code}
                    onClick={() => setSelectedPreset(preset)}
                    className={`p-4 rounded-xl border cursor-pointer transition-all ${
                      selectedPreset.code === preset.code
                        ? 'bg-blue-950/40 border-blue-500 shadow-md shadow-blue-500/10 ring-1 ring-blue-500'
                        : 'bg-slate-950/60 border-slate-800 hover:border-slate-700'
                    }`}
                  >
                    <div className="flex items-center justify-between mb-1.5">
                      <span className="text-xs font-bold font-mono text-cyan-300 bg-cyan-950/80 px-2 py-0.5 rounded border border-cyan-800/60">
                        {preset.code}
                      </span>
                      <span className="text-[11px] text-slate-400 font-medium">{preset.organization}</span>
                    </div>
                    <h5 className="text-sm font-bold text-white mb-1">{preset.title}</h5>
                    <p className="text-xs text-slate-400 line-clamp-2 leading-relaxed">
                      {preset.description}
                    </p>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* PDF Upload Mode */}
          {activeMode === 'pdf' && (
            <div className="space-y-4">
              <div className="border-2 border-dashed border-slate-700 hover:border-blue-500 rounded-2xl p-8 text-center transition bg-slate-950/40">
                <Upload className="w-10 h-10 text-blue-400 mx-auto mb-3" />
                <h4 className="text-sm font-bold text-white mb-1">
                  Glissez-déposez le document PDF officiel de la norme
                </h4>
                <p className="text-xs text-slate-400 mb-4">
                  Formats acceptés : .pdf, .txt, .docx (ex: ISO_527-2.pdf, NF_EN_196-1.pdf)
                </p>
                <label className="px-4 py-2 rounded-xl text-xs font-semibold bg-blue-600 hover:bg-blue-500 text-white cursor-pointer transition inline-block">
                  Parcourir les fichiers
                  <input
                    type="file"
                    accept=".pdf,.txt,.doc,.docx"
                    onChange={handleFileUpload}
                    className="hidden"
                  />
                </label>
                {uploadedFileName && (
                  <div className="mt-4 p-3 bg-blue-950/60 border border-blue-800 rounded-xl text-xs text-blue-300 font-mono inline-flex items-center space-x-2">
                    <FileText className="w-4 h-4" />
                    <span>Fichier chargé : {uploadedFileName}</span>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Raw Text Mode */}
          {activeMode === 'text' && (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-semibold text-slate-300 block mb-1">Code de la norme :</label>
                  <input
                    type="text"
                    value={customCode}
                    onChange={(e) => setCustomCode(e.target.value)}
                    placeholder="Ex: ISO 178 ou NF EN 12390-3"
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs font-mono text-white"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-slate-300 block mb-1">Domaine d application :</label>
                  <input
                    type="text"
                    value={customDomain}
                    onChange={(e) => setCustomDomain(e.target.value)}
                    placeholder="Ex: Plasturgie, Béton, Géotechnique"
                    className="w-full bg-slate-950 border border-slate-700 rounded-xl px-3 py-2 text-xs text-white"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-300 block mb-1">
                  Texte descriptif ou extrait de la norme (grandeurs, symboles et équations) :
                </label>
                <textarea
                  rows={6}
                  value={customText}
                  onChange={(e) => setCustomText(e.target.value)}
                  placeholder="Collez ici le texte brut de la norme..."
                  className="w-full bg-slate-950 border border-slate-700 rounded-xl p-3.5 text-xs font-mono text-slate-200 focus:outline-none focus:border-blue-500"
                />
              </div>
            </div>
          )}

          {/* Ingestion Processing Logs Terminal */}
          {isProcessing && (
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-4 space-y-3 font-mono text-xs shadow-inner">
              <div className="flex items-center justify-between text-blue-400 font-bold border-b border-slate-800 pb-2">
                <div className="flex items-center space-x-2">
                  <Terminal className="w-4 h-4 animate-pulse" />
                  <span>Pipeline d Ingestion PycnoLab en cours...</span>
                </div>
                <span>Étape {progressStep}/4</span>
              </div>

              <div className="space-y-1.5 text-slate-300 text-[11px]">
                {pipelineLogs.map((log, idx) => (
                  <div key={idx} className="flex items-center space-x-2">
                    <span className="text-cyan-400">❯</span>
                    <span>{log}</span>
                  </div>
                ))}
              </div>

              {/* Progress Bar */}
              <div className="w-full bg-slate-800 h-1.5 rounded-full overflow-hidden mt-3">
                <div
                  className="bg-gradient-to-r from-blue-500 to-cyan-400 h-full transition-all duration-300"
                  style={{ width: `${progressStep * 25}%` }}
                />
              </div>
            </div>
          )}

          {/* Error Message */}
          {errorMsg && (
            <div className="p-4 bg-rose-950/40 border border-rose-500/50 rounded-xl text-rose-300 text-xs flex items-center space-x-2">
              <AlertCircle className="w-5 h-5 flex-shrink-0" />
              <span>{errorMsg}</span>
            </div>
          )}
        </div>

        {/* Footer Actions */}
        <div className="px-6 py-4 border-t border-slate-800 bg-slate-850 flex items-center justify-between">
          <div className="text-xs text-slate-400 flex items-center space-x-1.5">
            <Bot className="w-4 h-4 text-cyan-400" />
            <span>Extraction assistée & pré-remplissage ~80% automatique</span>
          </div>

          <div className="flex items-center space-x-3">
            <button
              onClick={onClose}
              disabled={isProcessing}
              className="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white transition disabled:opacity-40"
            >
              Annuler
            </button>

            <button
              onClick={handleExecuteIngestion}
              disabled={isProcessing}
              className="px-5 py-2.5 rounded-xl text-xs font-semibold bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white shadow-md shadow-blue-600/30 transition flex items-center space-x-2 disabled:opacity-50"
            >
              <Sparkles className="w-4 h-4" />
              <span>{isProcessing ? 'Analyse en cours...' : 'Lancer l Ingestion & Ouvrir l Éditeur'}</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
