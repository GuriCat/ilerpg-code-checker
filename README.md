# ILE-RPG Code Checker

An MCP server that checks compliance with ILE-RPG syntax and coding standards.

## Overview

This MCP server analyzes ILE-RPG source code and detects issues such as:

- Specification order errors
- Column position rule violations
- Line continuation errors
- Naming convention violations
- Use of deprecated features
- Best practice violations

## Features

### Check Functions

1. **Structure Check**
   - Specification order (H→F→D→P→I→C→O)
   - Column position rules for each specification
   - Line length limit (maximum 100 columns)
   - DBCS (Double-Byte Character Set) support with shift character consideration

2. **Syntax Check**
   - Line continuation rule validation
   - Prohibition of multiple statements on one line
   - /FREE and /END-FREE correspondence
   - Correct use of **FREE format

3. **Naming Convention Check**
   - Variable and procedure name conventions
   - Special character usage restrictions
   - Meaningful name recommendations

4. **Best Practice Check**
   - Detection of deprecated features (GOTO, TAG, etc.)
   - Warning for numbered indicators
   - Recommendation for fully free format
   - Custom rule support

5. **Common Error Detection**
   - F-spec space shortage
   - D-spec column position errors
   - Continuation line errors

### Check Levels

- **basic**: Basic checks (specification order, critical syntax errors)
- **standard**: Standard checks (basic + column positions, line continuation, etc.)
- **strict**: Strict checks (standard + naming conventions, best practices)

### Multi-language Support

- **English (en)**: Default language
- **Japanese (ja)**: Full Japanese support for all messages and reports

### DBCS Support

When `considerDBCS` option is enabled, the checker accounts for shift-in (SI) and shift-out (SO) characters used in DBCS strings (Japanese, Chinese, Korean). This ensures accurate column position validation when DBCS characters are present.

### Custom Rules

Users can define custom best practice rules in a JSON file. Rules support:
- Pattern-based matching (regex)
- Custom severity levels
- Enable/disable functionality
- Rule descriptions and suggestions

## Installation

### Prerequisites

- Node.js 18 or higher
- npm

### Setup

1. Install dependencies:

```bash
cd /path/to/ilerpg-code-checker
npm install
```

2. Build:

```bash
npm run build
```

3. Add to MCP configuration file:

#### For IBM Bob IDE

Add the following to `c:\Users\user\AppData\Roaming\Bob-IDE\User\globalStorage\ibm.bob-code\settings\mcp_settings.json`:

```json
{
  "mcpServers": {
    "ilerpg-code-checker": {
      "command": "node",
      "args": ["<path-to-project>\\build\\index.js"],
      "disabled": false,
      "alwaysAllow": [],
      "disabledTools": []
    }
  }
}
```

#### For Claude Desktop

Add to your Claude Desktop MCP settings file (typically `~/Library/Application Support/Claude/claude_desktop_config.json` on macOS or `%APPDATA%\Claude\claude_desktop_config.json` on Windows):

```json
{
  "mcpServers": {
    "ilerpg-code-checker": {
      "command": "node",
      "args": ["<path-to-project>/build/index.js"]
    }
  }
}
```

#### For Cline (VS Code Extension)

Add to your Cline MCP settings in VS Code:

```json
{
  "mcpServers": {
    "ilerpg-code-checker": {
      "command": "node",
      "args": ["<path-to-project>/build/index.js"]
    }
  }
}
```

**Note:** Replace `<path-to-project>` with the actual absolute path to your ilerpg-code-checker directory.

## Usage

### MCP Tools

**Note on Token Efficiency:** When checking files, prefer using `check_rpg_file` over `check_rpg_code`. The `check_rpg_file` tool reads files directly on the server side, significantly reducing token usage compared to passing entire code content through `check_rpg_code`. This is especially important for large files or when checking multiple files.

#### 1. check_rpg_code

Checks entire RPG source code. **Note:** For better token efficiency, consider using `check_rpg_file` when checking files.

```typescript
use_mcp_tool({
  server_name: "ilerpg-code-checker",
  tool_name: "check_rpg_code",
  arguments: {
    code: "H DFTACTGRP(*NO)\n...",
    checkLevel: "standard",  // "basic" | "standard" | "strict"
    language: "en",          // "en" | "ja"
    considerDBCS: false,     // true to consider DBCS shift characters
    customRulesPath: "./custom-rules.json"  // Optional
  }
})
```

**Return value:**
```json
{
  "valid": false,
  "issues": [
    {
      "severity": "error",
      "category": "structure",
      "line": 10,
      "column": 7,
      "message": "Invalid specification order...",
      "rule": "SPEC_ORDER",
      "suggestion": "..."
    }
  ],
  "summary": {
    "totalIssues": 5,
    "errors": 2,
    "warnings": 2,
    "infos": 1,
    "checkedLines": 100
  }
}
```

#### 2. check_specification_order

Checks specification order only.

```typescript
use_mcp_tool({
  server_name: "ilerpg-code-checker",
  tool_name: "check_specification_order",
  arguments: {
    code: "H DFTACTGRP(*NO)\n...",
    language: "en"  // "en" | "ja"
  }
})
```

#### 3. check_column_positions

Checks column position rules.

```typescript
use_mcp_tool({
  server_name: "ilerpg-code-checker",
  tool_name: "check_column_positions",
  arguments: {
    code: "H DFTACTGRP(*NO)\n...",
    language: "en",       // "en" | "ja"
    considerDBCS: false   // true to consider DBCS shift characters
  }
})
```

#### 4. check_naming_conventions

Checks naming conventions.

```typescript
use_mcp_tool({
  server_name: "ilerpg-code-checker",
  tool_name: "check_naming_conventions",
  arguments: {
    code: "D MyVar           S             10A\n...",
    language: "en"  // "en" | "ja"
  }
})
```

#### 5. check_best_practices

Checks best practices.

```typescript
use_mcp_tool({
  server_name: "ilerpg-code-checker",
  tool_name: "check_best_practices",
  arguments: {
    code: "C                   GOTO      Label\n...",
    language: "en",                         // "en" | "ja"
    customRulesPath: "./custom-rules.json"  // Optional
  }
})
```

#### 6. check_rpg_file

Checks file by file. **Recommended:** This tool is more efficient than `check_rpg_code` as it reduces token usage by reading files directly on the server side.

```typescript
use_mcp_tool({
  server_name: "ilerpg-code-checker",
  tool_name: "check_rpg_file",
  arguments: {
    filePath: "//your-server/path/to/your-file.rpg",
    checkLevel: "standard",
    language: "en",          // "en" | "ja"
    considerDBCS: false,     // true to consider DBCS shift characters
    customRulesPath: "./custom-rules.json"  // Optional
  }
})
```

## Custom Rules

Create a JSON file to define custom best practice rules:

```json
{
  "rules": [
    {
      "id": "no-select-all",
      "name": "Avoid SELECT *",
      "description": "Using SELECT * is not recommended",
      "pattern": "SELECT\\s+\\*",
      "severity": "warning",
      "suggestion": "Specify column names explicitly",
      "enabled": true
    },
    {
      "id": "require-error-handling",
      "name": "Error handling required",
      "description": "All file operations should have error handling",
      "pattern": "CHAIN|READ|WRITE|UPDATE|DELETE",
      "severity": "info",
      "suggestion": "Add error handling with %ERROR or *IN99",
      "enabled": true
    }
  ]
}
```

### Custom Rule Properties

- `id`: Unique identifier for the rule
- `name`: Display name
- `description`: Detailed description
- `pattern`: Regular expression pattern to match
- `severity`: "error" | "warning" | "info"
- `suggestion`: Recommendation for fixing the issue
- `enabled`: true | false

## Examples of Detected Issues

### Structure Errors

```rpg
F-spec
H-spec  ← Error: H-spec must be placed before F-spec
```

### Column Position Errors

```rpg
D MyVariable    S             10A  ← Error: Variable name is not in correct column position
```

### Line Continuation Errors

```rpg
D MyLongVariableName
D-                    S             10A  ← Error: Continuation line spec type mismatch
```

### Naming Convention Violations

```rpg
D x               S             10A  ← Warning: Variable name is too short
D 1stVar          S             10A  ← Error: Variable name cannot start with a number
```

### Deprecated Features

```rpg
C                   GOTO      Label  ← Warning: GOTO is deprecated
C     Label        TAG
```

### DBCS Example

When `considerDBCS: true`:

```rpg
D MyVar           S             10A   INZ('日本語')
  ↑ Correctly accounts for shift characters in column position check
```

## Development

### Project Structure

```
e:\ilerpg-code-checker\
├── package.json
├── tsconfig.json
├── README.md
├── README.ja.md
├── PROJECT_STATUS.md
├── IMPLEMENTATION_DESIGN.md
├── CURRENT_STATUS_SUMMARY.md
├── src\
│   ├── index.ts              # MCP server entry point
│   ├── orchestrator.ts       # Check orchestration
│   ├── parser\
│   │   ├── rpg-parser.ts     # RPG code parser
│   │   └── line-analyzer.ts  # Line analysis
│   ├── checkers\
│   │   ├── structure-checker.ts
│   │   ├── syntax-checker.ts
│   │   ├── naming-checker.ts
│   │   ├── best-practice-checker.ts
│   │   └── common-errors-checker.ts
│   ├── i18n\
│   │   └── messages.ts       # Multi-language messages
│   ├── config\
│   │   └── custom-rules.ts   # Custom rules manager
│   ├── types\
│   │   └── index.ts          # Type definitions
│   └── utils\
│       ├── file-reader.ts
│       ├── reporter.ts
│       └── dbcs-helper.ts    # DBCS support utilities
└── build\
```

### Build

```bash
npm run build
```

### Development Mode (Auto-build)

```bash
npm run watch
```

## Troubleshooting

### MCP Server Won't Start

1. Check Node.js version: `node --version` (18 or higher required)
2. Verify build is complete: Check if `build/index.js` exists
3. Verify MCP configuration file path is correct

### Check Results Not Displayed

1. Check source code encoding (UTF-8 recommended)
2. Verify file path is correct
3. Check MCP server logs

## License

MIT

## Author

IBM Bob

## Version

0.0.2

## Changelog

### 0.0.2 (2026-01-25)
- Updated documentation
- Changed title from "ILE-RPG Coding Standards Checker" to "ILE-RPG Code Checker"
- Updated description to include "syntax and coding standards"
- Masked sensitive information in examples
- Fixed DBCS example to use INZ instead of Japanese variable names

### 0.0.1 (2026-01-25)
- Initial release
- Basic check functionality implementation
- 6 MCP tools provided
- Multi-language support (English/Japanese)
- DBCS character support
- Custom rules functionality

## References

- IBM i Information Center - ILE RPG Reference

## Support

For issues or questions, please report to the project's Issue tracker.