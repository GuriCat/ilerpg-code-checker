#!/usr/bin/env node

/**
 * ILE-RPG Coding Standards Checker - MCP Server
 * Model Context Protocol (MCP) server implementation
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool
} from '@modelcontextprotocol/sdk/types.js';
import { Orchestrator } from './orchestrator.js';
import { FileReader } from './utils/file-reader.js';
import { Reporter } from './utils/reporter.js';
import { CheckLevel, Language, CheckOptions } from './types/index.js';

/**
 * MCP Server class
 */
class RPGStandardsCheckerServer {
  private server: Server;
  private fileReader: FileReader;
  private readonly version = '0.0.4';

  constructor() {
    this.server = new Server(
      {
        name: 'ilerpg-code-checker',
        version: this.version
      },
      {
        capabilities: {
          tools: {}
        }
      }
    );

    this.fileReader = new FileReader();

    this.setupHandlers();
  }

  /**
   * Setup handlers
   */
  private setupHandlers(): void {
    // Get tool list
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: this.getTools()
    }));

    // Execute tool
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'check_rpg_code':
            return await this.handleCheckRPGCode(args);
          case 'check_specification_order':
            return await this.handleCheckSpecificationOrder(args);
          case 'check_column_positions':
            return await this.handleCheckColumnPositions(args);
          case 'check_naming_conventions':
            return await this.handleCheckNamingConventions(args);
          case 'check_best_practices':
            return await this.handleCheckBestPractices(args);
          case 'check_rpg_file':
            return await this.handleCheckRPGFile(args);
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        return {
          content: [
            {
              type: 'text',
              text: `Error occurred: ${errorMessage}`
            }
          ],
          isError: true
        };
      }
    });
  }

  /**
   * Define available tools
   */
  private getTools(): Tool[] {
    return [
      {
        name: 'check_rpg_code',
        description: 'Comprehensively check RPG code. Validates all items including structure, syntax, naming conventions, and best practices. Note: For better performance and reduced token usage, consider using check_rpg_file instead when checking files.',
        inputSchema: {
          type: 'object',
          properties: {
            code: {
              type: 'string',
              description: 'RPG source code to check'
            },
            checkLevel: {
              type: 'string',
              enum: ['basic', 'standard', 'strict'],
              description: 'Check level (basic, standard, strict)',
              default: 'standard'
            },
            language: {
              type: 'string',
              enum: ['en', 'ja'],
              description: 'Report language (en: English, ja: Japanese)',
              default: 'en'
            },
            considerDBCS: {
              type: 'boolean',
              description: 'Consider DBCS (Double-Byte Character Set) shift characters in column position checks',
              default: false
            },
            customRulesPath: {
              type: 'string',
              description: 'Path to custom rules JSON file'
            }
          },
          required: ['code']
        }
      },
      {
        name: 'check_specification_order',
        description: 'Check if specification order (H→F→D→P→I→C→O) is correct. Note: For better performance, consider using check_rpg_file for file-based checks.',
        inputSchema: {
          type: 'object',
          properties: {
            code: {
              type: 'string',
              description: 'RPG source code to check'
            },
            language: {
              type: 'string',
              enum: ['en', 'ja'],
              description: 'Report language (en: English, ja: Japanese)',
              default: 'en'
            }
          },
          required: ['code']
        }
      },
      {
        name: 'check_column_positions',
        description: 'Check if column position rules for each specification are correct. Note: For better performance, consider using check_rpg_file for file-based checks.',
        inputSchema: {
          type: 'object',
          properties: {
            code: {
              type: 'string',
              description: 'RPG source code to check'
            },
            language: {
              type: 'string',
              enum: ['en', 'ja'],
              description: 'Report language (en: English, ja: Japanese)',
              default: 'en'
            },
            considerDBCS: {
              type: 'boolean',
              description: 'Consider DBCS (Double-Byte Character Set) shift characters in column position checks',
              default: false
            }
          },
          required: ['code']
        }
      },
      {
        name: 'check_naming_conventions',
        description: 'Check naming conventions for variables, procedures, etc. Note: For better performance, consider using check_rpg_file for file-based checks.',
        inputSchema: {
          type: 'object',
          properties: {
            code: {
              type: 'string',
              description: 'RPG source code to check'
            },
            language: {
              type: 'string',
              enum: ['en', 'ja'],
              description: 'Report language (en: English, ja: Japanese)',
              default: 'en'
            }
          },
          required: ['code']
        }
      },
      {
        name: 'check_best_practices',
        description: 'Check best practices (use of deprecated features, indicators, etc.). Note: For better performance, consider using check_rpg_file for file-based checks.',
        inputSchema: {
          type: 'object',
          properties: {
            code: {
              type: 'string',
              description: 'RPG source code to check'
            },
            language: {
              type: 'string',
              enum: ['en', 'ja'],
              description: 'Report language (en: English, ja: Japanese)',
              default: 'en'
            },
            customRulesPath: {
              type: 'string',
              description: 'Path to custom rules JSON file'
            }
          },
          required: ['code']
        }
      },
      {
        name: 'check_rpg_file',
        description: 'Read and comprehensively check an RPG file. Recommended: This tool is more efficient than check_rpg_code as it reduces token usage by reading files directly instead of passing code content.',
        inputSchema: {
          type: 'object',
          properties: {
            filePath: {
              type: 'string',
              description: 'Path to RPG file to check'
            },
            checkLevel: {
              type: 'string',
              enum: ['basic', 'standard', 'strict'],
              description: 'Check level (basic, standard, strict)',
              default: 'standard'
            },
            language: {
              type: 'string',
              enum: ['en', 'ja'],
              description: 'Report language (en: English, ja: Japanese)',
              default: 'en'
            },
            considerDBCS: {
              type: 'boolean',
              description: 'Consider DBCS (Double-Byte Character Set) shift characters in column position checks',
              default: false
            },
            customRulesPath: {
              type: 'string',
              description: 'Path to custom rules JSON file'
            }
          },
          required: ['filePath']
        }
      }
    ];
  }

  /**
   * Handle check_rpg_code tool
   */
  private async handleCheckRPGCode(args: any) {
    const code = args.code as string;
    const checkLevel = (args.checkLevel as CheckLevel) || 'standard';
    const language = (args.language as Language) || 'en';
    const considerDBCS = args.considerDBCS === true;
    const customRulesPath = args.customRulesPath as string | undefined;

    const options: CheckOptions = {
      language,
      considerDBCS,
      customRulesPath
    };

    const orchestrator = new Orchestrator(options);
    const reporter = new Reporter(language);
    const result = orchestrator.checkCode(code, checkLevel);
    const report = reporter.formatMarkdown(result, { verbose: true, language });

    return {
      content: [
        {
          type: 'text',
          text: report
        }
      ]
    };
  }

  /**
   * Handle check_specification_order tool
   */
  private async handleCheckSpecificationOrder(args: any) {
    const code = args.code as string;
    const language = (args.language as Language) || 'en';

    const options: CheckOptions = { language };
    const orchestrator = new Orchestrator(options);
    const reporter = new Reporter(language);
    const result = orchestrator.checkSpecificationOrder(code);

    const msg = reporter['formatter'];
    let report = `# ${language === 'ja' ? '仕様書順序チェック結果' : 'Specification Order Check Result'}\n\n`;
    report += `**${msg.getMessage('result')}:** ${result.valid ? '✓ ' + (language === 'ja' ? '正しい順序です' : 'Correct order') : '✗ ' + (language === 'ja' ? '順序に問題があります' : 'Order issues found')}\n\n`;

    if (result.issues.length > 0) {
      report += `## ${msg.getMessage('detectedIssues')}\n\n`;
      for (const issue of result.issues) {
        report += `- **${msg.getMessage('line')}${issue.line}:** ${issue.message}\n`;
        if (issue.suggestion) {
          report += `  - **${msg.getMessage('suggestion')}:** ${issue.suggestion}\n`;
        }
      }
    }

    return {
      content: [
        {
          type: 'text',
          text: report
        }
      ]
    };
  }

  /**
   * Handle check_column_positions tool
   */
  private async handleCheckColumnPositions(args: any) {
    const code = args.code as string;
    const language = (args.language as Language) || 'en';
    const considerDBCS = args.considerDBCS === true;

    const options: CheckOptions = { language, considerDBCS };
    const orchestrator = new Orchestrator(options);
    const reporter = new Reporter(language);
    const result = orchestrator.checkColumnPositions(code);

    const msg = reporter['formatter'];
    let report = `# ${language === 'ja' ? '桁位置チェック結果' : 'Column Position Check Result'}\n\n`;
    report += `**${msg.getMessage('result')}:** ${result.valid ? '✓ ' + (language === 'ja' ? '桁位置は正しいです' : 'Column positions are correct') : '✗ ' + (language === 'ja' ? '桁位置に問題があります' : 'Column position issues found')}\n\n`;

    if (result.issues.length > 0) {
      report += `## ${msg.getMessage('detectedIssues')}\n\n`;
      for (const issue of result.issues) {
        const location = issue.column ? `${msg.getMessage('line')}${issue.line}:${issue.column}` : `${msg.getMessage('line')}${issue.line}`;
        report += `- **${location}:** ${issue.message}\n`;
        if (issue.suggestion) {
          report += `  - **${msg.getMessage('suggestion')}:** ${issue.suggestion}\n`;
        }
      }
    }

    return {
      content: [
        {
          type: 'text',
          text: report
        }
      ]
    };
  }

  /**
   * Handle check_naming_conventions tool
   */
  private async handleCheckNamingConventions(args: any) {
    const code = args.code as string;
    const language = (args.language as Language) || 'en';

    const options: CheckOptions = { language };
    const orchestrator = new Orchestrator(options);
    const reporter = new Reporter(language);
    const result = orchestrator.checkNamingConventions(code);

    const msg = reporter['formatter'];
    let report = `# ${language === 'ja' ? '命名規約チェック結果' : 'Naming Convention Check Result'}\n\n`;
    report += `**${msg.getMessage('result')}:** ${result.valid ? '✓ ' + (language === 'ja' ? '命名規約に準拠しています' : 'Complies with naming conventions') : '✗ ' + (language === 'ja' ? '命名規約に問題があります' : 'Naming convention issues found')}\n\n`;

    if (result.issues.length > 0) {
      report += `## ${msg.getMessage('detectedIssues')}\n\n`;
      for (const issue of result.issues) {
        report += `- **${msg.getMessage('line')}${issue.line}:** ${issue.message}\n`;
        if (issue.suggestion) {
          report += `  - **${msg.getMessage('suggestion')}:** ${issue.suggestion}\n`;
        }
      }
    }

    return {
      content: [
        {
          type: 'text',
          text: report
        }
      ]
    };
  }

  /**
   * Handle check_best_practices tool
   */
  private async handleCheckBestPractices(args: any) {
    const code = args.code as string;
    const language = (args.language as Language) || 'en';
    const customRulesPath = args.customRulesPath as string | undefined;

    const options: CheckOptions = { language, customRulesPath };
    const orchestrator = new Orchestrator(options);
    const reporter = new Reporter(language);
    const result = orchestrator.checkBestPractices(code);

    const msg = reporter['formatter'];
    let report = `# ${language === 'ja' ? 'ベストプラクティスチェック結果' : 'Best Practice Check Result'}\n\n`;
    report += `**${msg.getMessage('result')}:** ${result.valid ? '✓ ' + (language === 'ja' ? 'ベストプラクティスに準拠しています' : 'Complies with best practices') : '✗ ' + (language === 'ja' ? '改善の余地があります' : 'Room for improvement')}\n\n`;

    if (result.issues.length > 0) {
      report += `## ${msg.getMessage('detectedIssues')}\n\n`;
      for (const issue of result.issues) {
        report += `- **${msg.getMessage('line')}${issue.line}:** ${issue.message}\n`;
        if (issue.suggestion) {
          report += `  - **${msg.getMessage('suggestion')}:** ${issue.suggestion}\n`;
        }
      }
    }

    return {
      content: [
        {
          type: 'text',
          text: report
        }
      ]
    };
  }

  /**
   * Handle check_rpg_file tool
   */
  private async handleCheckRPGFile(args: any) {
    const filePath = args.filePath as string;
    const checkLevel = (args.checkLevel as CheckLevel) || 'standard';
    const language = (args.language as Language) || 'en';
    const considerDBCS = args.considerDBCS === true;
    const customRulesPath = args.customRulesPath as string | undefined;

    const options: CheckOptions = {
      language,
      considerDBCS,
      customRulesPath
    };

    // Read file
    const fileInfo = this.fileReader.readFileSync(filePath);
    
    // Execute check
    const orchestrator = new Orchestrator(options);
    const reporter = new Reporter(language);
    const result = orchestrator.checkCode(fileInfo.content, checkLevel, filePath);
    const report = reporter.formatMarkdown(result, { verbose: true, language });

    return {
      content: [
        {
          type: 'text',
          text: report
        }
      ]
    };
  }

  /**
   * Start server
   */
  async run(): Promise<void> {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error(`ILE RPG Code Checker MCP Server v${this.version} running on stdio`);
  }
}

// サーバーを起動
const server = new RPGStandardsCheckerServer();
server.run().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});