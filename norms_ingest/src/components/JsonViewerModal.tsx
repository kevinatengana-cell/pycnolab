import React, { useState } from 'react';
import { NormDraft } from '../types';
import { Braces, X, Copy, Check, Download, Edit3, Save } from 'lucide-react';

interface JsonViewerModalProps {
  isOpen: boolean;
  onClose: () => void;
  draft: NormDraft;
  onUpdateDraft?: (updated: NormDraft) => void;
}

export const JsonViewerModal: React.FC<JsonViewerModalProps> = ({
  isOpen,
  onClose,
  draft,
  onUpdateDraft,
}) => {
  const [copied, setCopied] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [jsonText, setJsonText] = useState(JSON.stringify(draft, null, 2));
  const [parseError, setParseError] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleCopy = () => {
    navigator.clipboard.writeText(JSON.stringify(draft, null, 2));
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDownload = () => {
    const blob = new Blob([JSON.stringify(draft, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${draft.draft_id || 'norm_draft'}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleSaveJsonEdit = () => {
    try {
      const parsed = JSON.parse(jsonText);
      if (onUpdateDraft) {
        onUpdateDraft(parsed);
      }
      setIsEditing(false);
      setParseError(null);
    } catch (err: any) {
      setParseError(err.message || 'JSON invalide');
    }
  };

  return (
    <div className="fixed inset-0 z-50 overflow-y-auto bg-black/75 backdrop-blur-sm flex items-center justify-center p-4 sm:p-6 animate-in fade-in duration-200">
      <div className="bg-slate-900 border border-slate-700 rounded-2xl w-full max-w-4xl overflow-hidden shadow-2xl flex flex-col max-h-[85vh]">
        {/* Header */}
        <div className="px-6 py-4 border-b border-slate-800 flex items-center justify-between bg-slate-850 flex-shrink-0">
          <div className="flex items-center space-x-3">
            <div className="w-8 h-8 rounded-lg bg-cyan-500/20 text-cyan-400 flex items-center justify-center">
              <Braces className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-base font-bold text-white flex items-center space-x-2">
                <span>JSON Intermédiaire de Pré-remplissage</span>
                <span className="text-xs font-mono px-2 py-0.5 rounded bg-cyan-950 text-cyan-300 border border-cyan-800/50">
                  ~80% Machine
                </span>
              </h3>
              <p className="text-xs text-slate-400">
                Structure de transfert Python / Flutter alimentant l écran EditeurProtocoleScreen
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            <button
              onClick={handleCopy}
              className="p-2 rounded-lg text-slate-300 hover:text-white hover:bg-slate-800 transition flex items-center space-x-1 text-xs"
              title="Copier dans le presse-papier"
            >
              {copied ? <Check className="w-4 h-4 text-emerald-400" /> : <Copy className="w-4 h-4" />}
              <span>{copied ? 'Copié !' : 'Copier'}</span>
            </button>

            <button
              onClick={handleDownload}
              className="p-2 rounded-lg text-slate-300 hover:text-white hover:bg-slate-800 transition flex items-center space-x-1 text-xs"
              title="Télécharger le fichier .json"
            >
              <Download className="w-4 h-4" />
              <span>Télécharger</span>
            </button>

            <button
              onClick={onClose}
              className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition ml-2"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Content */}
        <div className="p-6 overflow-y-auto flex-1 bg-slate-950 font-mono text-xs text-slate-300">
          {parseError && (
            <div className="mb-3 p-3 bg-rose-950/80 border border-rose-500 text-rose-200 rounded-xl text-xs">
              Erreur JSON : {parseError}
            </div>
          )}

          {isEditing ? (
            <textarea
              value={jsonText}
              onChange={(e) => setJsonText(e.target.value)}
              className="w-full h-96 bg-slate-900 border border-slate-700 rounded-xl p-4 text-xs font-mono text-cyan-300 focus:outline-none focus:border-blue-500"
            />
          ) : (
            <pre className="whitespace-pre-wrap leading-relaxed">
              {JSON.stringify(draft, null, 2)}
            </pre>
          )}
        </div>

        {/* Footer */}
        <div className="px-6 py-3.5 border-t border-slate-800 bg-slate-850 flex items-center justify-between flex-shrink-0">
          <div className="text-xs text-slate-400">
            {draft.extracted_inputs.length} inputs • {draft.extracted_formulas.length} formules • {draft.sandbox_test_cases.length} cas de test
          </div>

          <div className="flex items-center space-x-3">
            {isEditing ? (
              <>
                <button
                  onClick={() => setIsEditing(false)}
                  className="px-3 py-1.5 rounded-lg text-xs text-slate-400 hover:text-white transition"
                >
                  Annuler
                </button>
                <button
                  onClick={handleSaveJsonEdit}
                  className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-emerald-600 hover:bg-emerald-500 text-white transition flex items-center space-x-1"
                >
                  <Save className="w-3.5 h-3.5" />
                  <span>Appliquer les Modifications</span>
                </button>
              </>
            ) : (
              <button
                onClick={() => {
                  setJsonText(JSON.stringify(draft, null, 2));
                  setIsEditing(true);
                }}
                className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-200 transition flex items-center space-x-1 border border-slate-700"
              >
                <Edit3 className="w-3.5 h-3.5" />
                <span>Modifier le JSON Brute</span>
              </button>
            )}
            <button
              onClick={onClose}
              className="px-4 py-1.5 rounded-lg text-xs font-semibold bg-blue-600 hover:bg-blue-500 text-white transition"
            >
              Fermer
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
