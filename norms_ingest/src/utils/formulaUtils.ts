import { FormulaPill, InputVariable, VerificationStatus } from '../types';

export function normalizeUnit(raw: string): string {
  if (!raw) return 'mm';
  const clean = raw.trim();
  const map: Record<string, string> = {
    'KN': 'kN',
    'kn': 'kN',
    'N/MM2': 'MPa',
    'n/mm2': 'MPa',
    'N/mm²': 'MPa',
    'MPA': 'MPa',
    'mpa': 'MPa',
    'KG': 'kg',
    'g/cm3': 'g/cm³',
    'g/cm^3': 'g/cm³',
    'MM': 'mm',
    'CM': 'cm',
    'M': 'm',
    'DEGC': '°C',
    'degC': '°C',
    'celcius': '°C',
    'celsius': '°C',
    'KPA': 'kPa',
    'kpa': 'kPa',
    'BAR': 'bar',
    'PERCENT': '%',
    'pourcent': '%',
  };
  return map[clean] || map[clean.toUpperCase()] || clean;
}

export function tokenizeFormulaToPills(
  formulaStr: string,
  availableInputs: InputVariable[]
): FormulaPill[] {
  if (!formulaStr) return [];
  const pills: FormulaPill[] = [];
  
  // Sort keys by descending length to match longer names first
  const inputMap = new Map<string, InputVariable>();
  availableInputs.forEach((inp) => inputMap.set(inp.key, inp));

  // Regex tokenizer
  // Match variable tokens, numbers, operators, parentheses
  const tokenRegex = /([a-zA-Z_][a-zA-Z0-9_]*|\d+(?:\.\d+)?|[\+\-\*\/\^\(\)]|\s+)/g;
  let match;
  let pillIdx = 0;

  while ((match = tokenRegex.exec(formulaStr)) !== null) {
    const raw = match[0];
    if (/^\s+$/.test(raw)) continue;

    if (inputMap.has(raw)) {
      const inp = inputMap.get(raw)!;
      pills.push({
        id: `pill_${pillIdx++}`,
        text: inp.symbol ? `${inp.label} (${inp.symbol})` : inp.label,
        value: raw,
        category: 'variable',
        symbol: inp.symbol || raw,
      });
    } else if (/^\d+(\.\d+)?$/.test(raw)) {
      pills.push({
        id: `pill_${pillIdx++}`,
        text: raw,
        value: raw,
        category: 'number',
      });
    } else if (raw === '(' || raw === ')') {
      pills.push({
        id: `pill_${pillIdx++}`,
        text: raw,
        value: raw,
        category: 'parenthesis',
      });
    } else if (['+', '-', '*', '/', '^'].includes(raw)) {
      const opDisplay = raw === '*' ? '×' : raw === '/' ? '÷' : raw === '^' ? '^' : raw;
      pills.push({
        id: `pill_${pillIdx++}`,
        text: opDisplay,
        value: raw,
        category: 'operator',
      });
    } else if (['sqrt', 'min', 'max', 'abs'].includes(raw.toLowerCase())) {
      pills.push({
        id: `pill_${pillIdx++}`,
        text: raw,
        value: raw,
        category: 'function',
      });
    } else {
      // Unknown word identifier, treat as raw variable or symbol
      pills.push({
        id: `pill_${pillIdx++}`,
        text: raw,
        value: raw,
        category: 'variable',
        symbol: raw,
      });
    }
  }

  return pills;
}

export function pillsToFormulaString(pills: FormulaPill[]): string {
  return pills.map((p) => p.value).join(' ');
}

export interface FormulaValidationResult {
  isValid: boolean;
  message?: string;
  astFormatted?: string;
  missingVariables: string[];
}

export function validateFormulaSyntax(
  formulaStr: string,
  availableKeys: string[]
): FormulaValidationResult {
  if (!formulaStr || !formulaStr.trim()) {
    return {
      isValid: false,
      message: 'La formule ne peut pas être vide.',
      missingVariables: [],
    };
  }

  // Parentheses check
  let parenBalance = 0;
  for (let i = 0; i < formulaStr.length; i++) {
    if (formulaStr[i] === '(') parenBalance++;
    if (formulaStr[i] === ')') parenBalance--;
    if (parenBalance < 0) {
      return {
        isValid: false,
        message: 'Parenthèse fermante inattendue sans parenthèse ouvrante correspondante.',
        missingVariables: [],
      };
    }
  }
  if (parenBalance !== 0) {
    return {
      isValid: false,
      message: `Parenthèses non équilibrées (${Math.abs(parenBalance)} non fermée(s)).`,
      missingVariables: [],
    };
  }

  // Check missing variables
  const idRegex = /\b[a-zA-Z_][a-zA-Z0-9_]*\b/g;
  const missing: string[] = [];
  let m;
  const knownKeywords = new Set(['sqrt', 'min', 'max', 'abs', 'math', 'pi', 'e', 'exp']);
  const availableSet = new Set(availableKeys);

  while ((m = idRegex.exec(formulaStr)) !== null) {
    const id = m[0];
    if (!knownKeywords.has(id.toLowerCase()) && !availableSet.has(id)) {
      missing.push(id);
    }
  }

  if (missing.length > 0) {
    return {
      isValid: false,
      message: `Variables non reconnues : ${missing.join(', ')}. Ajoutez-les aux entrées ou corrigez l'orthographe.`,
      missingVariables: missing,
    };
  }

  // Test evaluation with dummy 1.0 values
  try {
    const testVars: Record<string, number> = {};
    availableKeys.forEach((k) => (testVars[k] = 2.0));
    evaluateFormulaClient(formulaStr, testVars);
    return {
      isValid: true,
      astFormatted: formulaStr,
      missingVariables: [],
    };
  } catch (err: any) {
    return {
      isValid: false,
      message: `Erreur d'évaluation syntaxique : ${err.message || 'Expression invalide'}`,
      missingVariables: [],
    };
  }
}

export function evaluateFormulaClient(
  formula: string,
  vars: Record<string, number>
): number {
  if (!formula || !formula.trim()) return 0;
  let expr = formula;

  // Replace variable keys with numeric values
  const sortedKeys = Object.keys(vars).sort((a, b) => b.length - a.length);
  for (const key of sortedKeys) {
    const val = vars[key] !== undefined ? vars[key] : 0;
    const regex = new RegExp(`\\b${key}\\b`, 'g');
    expr = expr.replace(regex, `(${val})`);
  }

  expr = expr.replace(/sqrt\(/g, 'Math.sqrt(');
  expr = expr.replace(/\^/g, '**');

  // Security whitelist check
  if (/[^0-9\.\+\-\*\/\(\)\sMath\.sqrtpowminmaxabs\,\*]/g.test(expr)) {
    throw new Error('Caractères interdits dans l expression mathématique');
  }

  // eslint-disable-next-line no-new-func
  const result = Function(`"use strict"; return (${expr});`)();
  if (typeof result !== 'number' || isNaN(result) || !isFinite(result)) {
    throw new Error('Résultat indéfini ou division par zéro');
  }
  return result;
}
