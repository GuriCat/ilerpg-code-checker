/**
 * ILE-RPG Coding Standards Checker - Custom Rules Manager
 * Allows users to add, remove, and edit best practice rules
 */

import * as fs from 'fs';
import * as path from 'path';
import { ParsedLine, Issue, Category, Severity } from '../types/index.js';

/**
 * Custom rule definition
 */
export interface CustomRule {
  id: string;
  name: string;
  description: string;
  category: Category;
  severity: Severity;
  enabled: boolean;
  pattern?: string; // Regex pattern to match
  checkFunction?: string; // Custom check function (as string for serialization)
  message: string;
  suggestion?: string;
}

/**
 * Custom rules configuration
 */
export interface CustomRulesConfig {
  version: string;
  rules: CustomRule[];
}

/**
 * Custom Rules Manager
 * Manages user-defined best practice rules
 */
export class CustomRulesManager {
  private configPath: string;
  private config: CustomRulesConfig;

  constructor(configPath?: string) {
    this.configPath = configPath || path.join(process.cwd(), 'rpg-custom-rules.json');
    this.config = this.loadConfig();
  }

  /**
   * Load configuration from file
   */
  private loadConfig(): CustomRulesConfig {
    try {
      if (fs.existsSync(this.configPath)) {
        const content = fs.readFileSync(this.configPath, 'utf-8');
        return JSON.parse(content);
      }
    } catch (error) {
      console.error('Failed to load custom rules config:', error);
    }

    // Return default config
    return {
      version: '1.0.0',
      rules: []
    };
  }

  /**
   * Save configuration to file
   */
  private saveConfig(): void {
    try {
      const content = JSON.stringify(this.config, null, 2);
      fs.writeFileSync(this.configPath, content, 'utf-8');
    } catch (error) {
      console.error('Failed to save custom rules config:', error);
      throw new Error(`Failed to save custom rules: ${error}`);
    }
  }

  /**
   * Get all custom rules
   */
  getRules(): CustomRule[] {
    return this.config.rules;
  }

  /**
   * Get enabled custom rules
   */
  getEnabledRules(): CustomRule[] {
    return this.config.rules.filter(rule => rule.enabled);
  }

  /**
   * Get rule by ID
   */
  getRule(id: string): CustomRule | undefined {
    return this.config.rules.find(rule => rule.id === id);
  }

  /**
   * Add a new custom rule
   */
  addRule(rule: CustomRule): void {
    // Check if rule with same ID already exists
    if (this.config.rules.some(r => r.id === rule.id)) {
      throw new Error(`Rule with ID '${rule.id}' already exists`);
    }

    this.config.rules.push(rule);
    this.saveConfig();
  }

  /**
   * Update an existing custom rule
   */
  updateRule(id: string, updates: Partial<CustomRule>): void {
    const index = this.config.rules.findIndex(rule => rule.id === id);
    if (index === -1) {
      throw new Error(`Rule with ID '${id}' not found`);
    }

    // Don't allow changing the ID
    if (updates.id && updates.id !== id) {
      throw new Error('Cannot change rule ID');
    }

    this.config.rules[index] = {
      ...this.config.rules[index],
      ...updates
    };
    this.saveConfig();
  }

  /**
   * Remove a custom rule
   */
  removeRule(id: string): void {
    const index = this.config.rules.findIndex(rule => rule.id === id);
    if (index === -1) {
      throw new Error(`Rule with ID '${id}' not found`);
    }

    this.config.rules.splice(index, 1);
    this.saveConfig();
  }

  /**
   * Enable a rule
   */
  enableRule(id: string): void {
    this.updateRule(id, { enabled: true });
  }

  /**
   * Disable a rule
   */
  disableRule(id: string): void {
    this.updateRule(id, { enabled: false });
  }

  /**
   * Check a line against custom rules
   */
  checkLine(line: ParsedLine): Issue[] {
    const issues: Issue[] = [];
    const enabledRules = this.getEnabledRules();

    for (const rule of enabledRules) {
      const issue = this.applyRule(rule, line);
      if (issue) {
        issues.push(issue);
      }
    }

    return issues;
  }

  /**
   * Apply a single rule to a line
   */
  private applyRule(rule: CustomRule, line: ParsedLine): Issue | null {
    // Skip comment lines
    if (line.isComment) return null;

    // Pattern-based check
    if (rule.pattern) {
      try {
        const regex = new RegExp(rule.pattern, 'i');
        if (regex.test(line.rawContent)) {
          return {
            severity: rule.severity,
            category: rule.category,
            line: line.lineNumber,
            message: rule.message,
            rule: rule.id,
            ruleDescription: rule.description,
            suggestion: rule.suggestion,
            codeSnippet: line.rawContent
          };
        }
      } catch (error) {
        console.error(`Invalid regex pattern in rule '${rule.id}':`, error);
      }
    }

    return null;
  }

  /**
   * Export rules to JSON string
   */
  exportRules(): string {
    return JSON.stringify(this.config, null, 2);
  }

  /**
   * Import rules from JSON string
   */
  importRules(jsonString: string, merge: boolean = false): void {
    try {
      const imported: CustomRulesConfig = JSON.parse(jsonString);
      
      if (!imported.rules || !Array.isArray(imported.rules)) {
        throw new Error('Invalid rules format');
      }

      if (merge) {
        // Merge with existing rules
        for (const rule of imported.rules) {
          const existingIndex = this.config.rules.findIndex(r => r.id === rule.id);
          if (existingIndex >= 0) {
            // Update existing rule
            this.config.rules[existingIndex] = rule;
          } else {
            // Add new rule
            this.config.rules.push(rule);
          }
        }
      } else {
        // Replace all rules
        this.config = imported;
      }

      this.saveConfig();
    } catch (error) {
      throw new Error(`Failed to import rules: ${error}`);
    }
  }

  /**
   * Reset to default (empty) configuration
   */
  reset(): void {
    this.config = {
      version: '1.0.0',
      rules: []
    };
    this.saveConfig();
  }

  /**
   * Get configuration file path
   */
  getConfigPath(): string {
    return this.configPath;
  }
}