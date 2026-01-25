/**
 * ILE-RPG Coding Standards Checker - Report Generation Utility
 * Formats and outputs check results
 */

import { CheckResult, Issue, ReportOptions, Language } from '../types/index.js';
import { MessageFormatter } from '../i18n/messages.js';

/**
 * Reporter class
 * Formats check results in various formats
 */
export class Reporter {
  private formatter: MessageFormatter;

  constructor(language: Language = 'en') {
    this.formatter = new MessageFormatter(language);
  }

  /**
   * Set language
   * @param language Language code
   */
  setLanguage(language: Language): void {
    this.formatter.setLanguage(language);
  }

  /**
   * Format check result as text
   * @param result Check result
   * @param options Report options
   * @returns Formatted text
   */
  formatText(result: CheckResult, options: ReportOptions = {}): string {
    const { verbose = false, color = false, language } = options;
    if (language) {
      this.formatter.setLanguage(language);
    }
    
    const lines: string[] = [];
    const msg = this.formatter;

    // Header
    lines.push('='.repeat(80));
    lines.push(msg.getMessage('checkResult'));
    lines.push('='.repeat(80));
    lines.push('');

    // File information
    if (result.filePath) {
      lines.push(`${msg.getMessage('file')}: ${result.filePath}`);
      lines.push('');
    }

    // Summary
    lines.push(`【${msg.getMessage('summary')}】`);
    lines.push(`${msg.getMessage('totalIssues')}: ${result.summary.totalIssues}`);
    lines.push(`  ${msg.getMessage('errors')}: ${result.summary.errors}`);
    lines.push(`  ${msg.getMessage('warnings')}: ${result.summary.warnings}`);
    lines.push(`  ${msg.getMessage('infos')}: ${result.summary.infos}`);
    lines.push(`${msg.getMessage('checkedLines')}: ${result.summary.checkedLines}`);
    lines.push('');

    // Specification type statistics
    if (verbose) {
      lines.push(`【${msg.getMessage('specStats')}】`);
      const specs = result.summary.specificationCounts;
      if (specs.H > 0) lines.push(`  ${msg.getMessage('hSpec')}: ${specs.H}${msg.getMessage('lines')}`);
      if (specs.F > 0) lines.push(`  ${msg.getMessage('fSpec')}: ${specs.F}${msg.getMessage('lines')}`);
      if (specs.D > 0) lines.push(`  ${msg.getMessage('dSpec')}: ${specs.D}${msg.getMessage('lines')}`);
      if (specs.P > 0) lines.push(`  ${msg.getMessage('pSpec')}: ${specs.P}${msg.getMessage('lines')}`);
      if (specs.I > 0) lines.push(`  ${msg.getMessage('iSpec')}: ${specs.I}${msg.getMessage('lines')}`);
      if (specs.C > 0) lines.push(`  ${msg.getMessage('cSpec')}: ${specs.C}${msg.getMessage('lines')}`);
      if (specs.O > 0) lines.push(`  ${msg.getMessage('oSpec')}: ${specs.O}${msg.getMessage('lines')}`);
      if (specs.FREE > 0) lines.push(`  **FREE: ${specs.FREE}${msg.getMessage('lines')}`);
      if (specs.COMMENT > 0) lines.push(`  ${msg.getMessage('comment')}: ${specs.COMMENT}${msg.getMessage('lines')}`);
      lines.push('');
    }

    // Issue details
    if (result.issues.length > 0) {
      lines.push(`【${msg.getMessage('detectedIssues')}】`);
      lines.push('');

      for (const issue of result.issues) {
        lines.push(this.formatIssue(issue, color, verbose));
        lines.push('');
      }
    } else {
      lines.push(msg.getMessage('noIssues'));
      lines.push('');
    }

    // Footer
    lines.push('='.repeat(80));
    lines.push(`${msg.getMessage('result')}: ${result.valid ? '✓ ' + msg.getMessage('passed') : '✗ ' + msg.getMessage('failed')}`);
    lines.push('='.repeat(80));

    return lines.join('\n');
  }

  /**
   * Format individual issue
   * @param issue Issue
   * @param color Use color output
   * @param verbose Show details
   * @returns Formatted text
   */
  private formatIssue(issue: Issue, color: boolean, verbose: boolean): string {
    const lines: string[] = [];
    const msg = this.formatter;

    // Severity icon
    const severityIcon = this.getSeverityIcon(issue.severity);
    const severityText = color ? this.colorize(severityIcon, issue.severity) : severityIcon;

    // Basic information
    const location = issue.column
      ? `${msg.getMessage('line')}${issue.line}:${issue.column}`
      : `${msg.getMessage('line')}${issue.line}`;
    
    lines.push(`${severityText} ${location} - ${issue.message}`);

    // Rule information
    if (verbose && issue.rule) {
      lines.push(`  ${msg.getMessage('rule')}: ${issue.rule}`);
      if (issue.ruleDescription) {
        lines.push(`  ${msg.getMessage('description')}: ${issue.ruleDescription}`);
      }
    }

    // Suggestion
    if (issue.suggestion) {
      lines.push(`  ${msg.getMessage('suggestion')}: ${issue.suggestion}`);
    }

    // Code snippet
    if (verbose && issue.codeSnippet) {
      lines.push(`  ${msg.getMessage('code')}: ${issue.codeSnippet}`);
    }

    return lines.join('\n');
  }

  /**
   * Format check result as JSON
   * @param result Check result
   * @param pretty Pretty print
   * @returns JSON string
   */
  formatJSON(result: CheckResult, pretty: boolean = true): string {
    return pretty 
      ? JSON.stringify(result, null, 2)
      : JSON.stringify(result);
  }

  /**
   * Format check result as Markdown
   * @param result Check result
   * @param options Report options
   * @returns Markdown string
   */
  formatMarkdown(result: CheckResult, options: ReportOptions = {}): string {
    const { verbose = false, language } = options;
    if (language) {
      this.formatter.setLanguage(language);
    }
    
    const lines: string[] = [];
    const msg = this.formatter;

    // Header
    lines.push(`# ${msg.getMessage('checkResult')}`);
    lines.push('');

    // File information
    if (result.filePath) {
      lines.push(`**${msg.getMessage('file')}:** \`${result.filePath}\``);
      lines.push('');
    }

    // Summary
    lines.push(`## ${msg.getMessage('summary')}`);
    lines.push('');
    lines.push(`| ${msg.getMessage('item')} | ${msg.getMessage('value')} |`);
    lines.push('|------|---:|');
    lines.push(`| ${msg.getMessage('totalIssues')} | ${result.summary.totalIssues} |`);
    lines.push(`| ${msg.getMessage('errors')} | ${result.summary.errors} |`);
    lines.push(`| ${msg.getMessage('warnings')} | ${result.summary.warnings} |`);
    lines.push(`| ${msg.getMessage('infos')} | ${result.summary.infos} |`);
    lines.push(`| ${msg.getMessage('checkedLines')} | ${result.summary.checkedLines} |`);
    lines.push('');

    // Result
    const status = result.valid ? `✓ ${msg.getMessage('passed')}` : `✗ ${msg.getMessage('failed')}`;
    const statusBadge = result.valid
      ? `![${msg.getMessage('passed')}](https://img.shields.io/badge/${msg.getMessage('result')}-${msg.getMessage('passed')}-success)`
      : `![${msg.getMessage('failed')}](https://img.shields.io/badge/${msg.getMessage('result')}-${msg.getMessage('failed')}-critical)`;
    lines.push(`**${msg.getMessage('result')}:** ${statusBadge} ${status}`);
    lines.push('');

    // Issue details
    if (result.issues.length > 0) {
      lines.push(`## ${msg.getMessage('detectedIssues')}`);
      lines.push('');

      // Group by severity
      const errors = result.issues.filter(i => i.severity === 'error');
      const warnings = result.issues.filter(i => i.severity === 'warning');
      const infos = result.issues.filter(i => i.severity === 'info');

      if (errors.length > 0) {
        lines.push(`### ${msg.getMessage('errors')}`);
        lines.push('');
        for (const issue of errors) {
          lines.push(this.formatIssueMarkdown(issue, verbose));
        }
      }

      if (warnings.length > 0) {
        lines.push(`### ${msg.getMessage('warnings')}`);
        lines.push('');
        for (const issue of warnings) {
          lines.push(this.formatIssueMarkdown(issue, verbose));
        }
      }

      if (infos.length > 0) {
        lines.push(`### ${msg.getMessage('infos')}`);
        lines.push('');
        for (const issue of infos) {
          lines.push(this.formatIssueMarkdown(issue, verbose));
        }
      }
    } else {
      lines.push(`## ${msg.getMessage('result')}`);
      lines.push('');
      lines.push(`✓ ${msg.getMessage('noIssues')}`);
      lines.push('');
    }

    return lines.join('\n');
  }

  /**
   * Format individual issue as Markdown
   * @param issue Issue
   * @param verbose Show details
   * @returns Markdown string
   */
  private formatIssueMarkdown(issue: Issue, verbose: boolean): string {
    const lines: string[] = [];
    const msg = this.formatter;

    // Basic information
    const location = issue.column
      ? `**${msg.getMessage('line')}${issue.line}:${issue.column}**`
      : `**${msg.getMessage('line')}${issue.line}**`;
    
    lines.push(`- ${location} - ${issue.message}`);

    // Rule information
    if (verbose && issue.rule) {
      lines.push(`  - **${msg.getMessage('rule')}:** \`${issue.rule}\``);
      if (issue.ruleDescription) {
        lines.push(`  - **${msg.getMessage('description')}:** ${issue.ruleDescription}`);
      }
    }

    // Suggestion
    if (issue.suggestion) {
      lines.push(`  - **${msg.getMessage('suggestion')}:** ${issue.suggestion}`);
    }

    // Code snippet
    if (verbose && issue.codeSnippet) {
      lines.push(`  - **${msg.getMessage('code')}:** \`${issue.codeSnippet}\``);
    }

    lines.push('');
    return lines.join('\n');
  }

  /**
   * Get icon for severity
   * @param severity Severity level
   * @returns Icon string
   */
  private getSeverityIcon(severity: string): string {
    const msg = this.formatter;
    switch (severity) {
      case 'error':
        return `✗ [${msg.getMessage('error')}]`;
      case 'warning':
        return `⚠ [${msg.getMessage('warning')}]`;
      case 'info':
        return `ℹ [${msg.getMessage('info')}]`;
      default:
        return `[${msg.getMessage('unknown')}]`;
    }
  }

  /**
   * Colorize text (ANSI escape sequences)
   * @param text Text
   * @param severity Severity level
   * @returns Colorized text
   */
  private colorize(text: string, severity: string): string {
    const colors = {
      error: '\x1b[31m',   // Red
      warning: '\x1b[33m', // Yellow
      info: '\x1b[36m',    // Cyan
      reset: '\x1b[0m'
    };

    const color = colors[severity as keyof typeof colors] || '';
    return `${color}${text}${colors.reset}`;
  }

  /**
   * Format summary only
   * @param result Check result
   * @returns Formatted text
   */
  formatSummary(result: CheckResult, language?: Language): string {
    if (language) {
      this.formatter.setLanguage(language);
    }
    const msg = this.formatter;
    const status = result.valid ? `✓ ${msg.getMessage('passed')}` : `✗ ${msg.getMessage('failed')}`;
    return `${status} - ${msg.getMessage('errors')}: ${result.summary.errors}, ${msg.getMessage('warnings')}: ${result.summary.warnings}, ${msg.getMessage('infos')}: ${result.summary.infos}`;
  }
}