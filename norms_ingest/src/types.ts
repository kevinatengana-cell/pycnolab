export type VariableType = 'decimal' | 'integer' | 'select' | 'boolean';
export type VerificationStatus = 'verified' | 'needs_review' | 'manual_addition';
export type ProtocolStatus = 'DRAFT_PARSED' | 'IN_REVIEW' | 'ACTIVE' | 'ARCHIVED';

export interface InputVariable {
  id: string;
  key: string;
  label: string;
  symbol: string;
  unit: string;
  type: VariableType;
  status: VerificationStatus;
  confidence: number;
  defaultValue?: number;
  min?: number;
  max?: number;
  description?: string;
  options?: string[];
}

export type PillCategory = 'variable' | 'operator' | 'number' | 'function' | 'parenthesis';

export interface FormulaPill {
  id: string;
  text: string;
  value: string;
  category: PillCategory;
  symbol?: string;
}

export interface FormulaDefinition {
  id: string;
  output_key: string;
  label: string;
  symbol: string;
  unit: string;
  raw_detected_formula: string;
  status: VerificationStatus;
  confidence: number;
  decimals?: number;
  description?: string;
  pills?: FormulaPill[];
}

export interface SandboxTestCase {
  id: string;
  name: string;
  inputs: Record<string, number>;
  expected_outputs: Record<string, { value: number; tolerancePct: number }>;
  notes?: string;
}

export interface IngestionLogItem {
  step: string;
  timestamp: string;
  message: string;
  type: 'info' | 'success' | 'warning' | 'regex' | 'ast';
}

export interface NormMetadata {
  norme: string;
  titre: string;
  organisme: string;
  domaine: string;
  annee_edition?: string;
  confidence: number;
  description?: string;
  conditions_nominales?: {
    temperature?: string;
    hygrometrie?: string;
    vitesse_essai?: string;
  };
}

export interface NormDraft {
  draft_id: string;
  status: ProtocolStatus;
  metadata: NormMetadata;
  extracted_inputs: InputVariable[];
  extracted_formulas: FormulaDefinition[];
  sandbox_test_cases: SandboxTestCase[];
  source?: 'gemini_ai_parser' | 'deterministic_regex_parser' | 'manual';
  created_at: string;
  updated_at: string;
  reviewed_by?: string;
  notes?: string;
}

export interface StandardPreset {
  code: string;
  title: string;
  domain: string;
  organization: string;
  badgeColor: string;
  description: string;
  sampleText: string;
  draft: Omit<NormDraft, 'created_at' | 'updated_at'>;
}

export interface ActiveTestRun {
  id: string;
  normCode: string;
  protocolName: string;
  sampleId: string;
  operator: string;
  timestamp: string;
  inputValues: Record<string, number>;
  calculatedOutputs: Record<string, number>;
  isConform: boolean;
  notes?: string;
}
