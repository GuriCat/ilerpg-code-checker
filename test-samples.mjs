import { Orchestrator } from './build/orchestrator.js';
import fs from 'fs';
import path from 'path';

const samplesDir = './saples';
const files = fs.readdirSync(samplesDir).filter(f => f.endsWith('.rpgle'));

const options = { language: 'ja', considerDBCS: true };
const orchestrator = new Orchestrator(options);

for (const file of files) {
  const filePath = path.join(samplesDir, file);
  const content = fs.readFileSync(filePath, 'utf-8');
  const result = orchestrator.checkCode(content, 'standard', filePath);

  const errors = result.issues.filter(i => i.severity === 'error');
  const warnings = result.issues.filter(i => i.severity === 'warning');

  console.log(`\n=== ${file} ===`);
  console.log(`  Errors: ${errors.length}, Warnings: ${warnings.length}`);

  for (const issue of errors) {
    console.log(`  ERROR L${issue.line}: [${issue.rule || 'unknown'}] ${issue.message}`);
  }
  for (const issue of warnings) {
    console.log(`  WARN  L${issue.line}: [${issue.rule || 'unknown'}] ${issue.message}`);
  }
}
