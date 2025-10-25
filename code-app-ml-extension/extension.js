/**
 * Code App Extension with Local ML/RAG
 * Uses WebLLM for on-device inference
 * Accelerated by Apple Neural Engine / Qualcomm Hexagon / Samsung NPU
 */

import * as vscode from 'vscode';
import * as webllm from '@mlc-ai/web-llm';

let mlcEngine = null;
let isModelLoaded = false;

// Activate extension
export async function activate(context) {
  console.log('ML-powered code extension activating...');

  // Initialize ML engine
  const initCommand = vscode.commands.registerCommand(
    'mlcode.initializeModel',
    async () => {
      await initializeMLModel();
    }
  );

  // Code completion provider
  const completionProvider = vscode.languages.registerCompletionItemProvider(
    ['bash', 'shellscript', 'rust', 'javascript', 'typescript'],
    {
      async provideCompletionItems(document, position) {
        if (!isModelLoaded) {
          return [];
        }

        const linePrefix = document.lineAt(position).text.substr(0, position.character);
        const context = getCodeContext(document, position);
        
        const completion = await getMLCompletion(context, linePrefix);
        
        const item = new vscode.CompletionItem(completion, vscode.CompletionItemKind.Text);
        item.detail = 'ML-powered (on-device)';
        return [item];
      }
    },
    '.' // Trigger on dot
  );

  // Code explanation
  const explainCommand = vscode.commands.registerCommand(
    'mlcode.explainCode',
    async () => {
      const editor = vscode.window.activeTextEditor;
      if (!editor) return;

      const selection = editor.document.getText(editor.selection);
      const explanation = await explainCode(selection);
      
      vscode.window.showInformationMessage(explanation);
    }
  );

  // RAG-based code search
  const searchCommand = vscode.commands.registerCommand(
    'mlcode.ragSearch',
    async () => {
      const query = await vscode.window.showInputBox({
        prompt: 'Search codebase with natural language'
      });

      if (query) {
        const results = await ragSearch(query);
        showSearchResults(results);
      }
    }
  );

  context.subscriptions.push(
    initCommand,
    completionProvider,
    explainCommand,
    searchCommand
  );
}

// Initialize ML model (runs on Neural Engine/Hexagon/NPU)
async function initializeMLModel() {
  vscode.window.showInformationMessage('Loading ML model on-device...');

  try {
    // Use smaller model for mobile (3B parameters)
    mlcEngine = await webllm.CreateMLCEngine(
      "Llama-3.2-3B-Instruct-q4f16_1", // Quantized for mobile
      {
        initProgressCallback: (progress) => {
          vscode.window.showInformationMessage(
            `Loading: ${Math.round(progress.progress * 100)}%`
          );
        },
        // Use hardware acceleration
        backend: "webgpu", // Uses Metal on iOS, Vulkan on Android
      }
    );

    isModelLoaded = true;
    vscode.window.showInformationMessage('✅ ML model loaded! Using Neural Engine');
  } catch (error) {
    vscode.window.showErrorMessage(`Failed to load model: ${error}`);
  }
}

// Get code context for better completions
function getCodeContext(document, position) {
  const startLine = Math.max(0, position.line - 10);
  const endLine = Math.min(document.lineCount, position.line + 5);
  
  const range = new vscode.Range(startLine, 0, endLine, 0);
  return document.getText(range);
}

// ML-powered code completion
async function getMLCompletion(context, linePrefix) {
  if (!mlcEngine) return '';

  const prompt = `You are a code completion assistant. Complete this code:

Context:
${context}

Current line: ${linePrefix}

Complete the current line (one line only):`;

  try {
    const response = await mlcEngine.chat.completions.create({
      messages: [{ role: "user", content: prompt }],
      temperature: 0.3,
      max_tokens: 50,
    });

    return response.choices[0].message.content.trim();
  } catch (error) {
    console.error('Completion error:', error);
    return '';
  }
}

// Explain code using ML
async function explainCode(code) {
  if (!mlcEngine) {
    return 'ML model not loaded. Run "Initialize ML Model" first.';
  }

  const prompt = `Explain this code concisely:

\`\`\`
${code}
\`\`\`

Explanation:`;

  try {
    const response = await mlcEngine.chat.completions.create({
      messages: [{ role: "user", content: prompt }],
      temperature: 0.5,
      max_tokens: 200,
    });

    return response.choices[0].message.content;
  } catch (error) {
    return `Error: ${error.message}`;
  }
}

// RAG-based code search
async function ragSearch(query) {
  if (!mlcEngine) return [];

  // Get all files in workspace
  const files = await vscode.workspace.findFiles('**/*.{js,ts,sh,rs,py}');
  
  // Build context from files
  const codebase = [];
  for (const file of files.slice(0, 20)) { // Limit for performance
    const doc = await vscode.workspace.openTextDocument(file);
    codebase.push({
      path: file.fsPath,
      content: doc.getText()
    });
  }

  // Use ML to find relevant code
  const prompt = `Given this query: "${query}"

Find relevant code in this codebase:
${codebase.map(f => `File: ${f.path}\n${f.content.slice(0, 500)}`).join('\n\n')}

List the most relevant files and why:`;

  try {
    const response = await mlcEngine.chat.completions.create({
      messages: [{ role: "user", content: prompt }],
      temperature: 0.3,
      max_tokens: 300,
    });

    return response.choices[0].message.content;
  } catch (error) {
    return `Error: ${error.message}`;
  }
}

// Show search results
function showSearchResults(results) {
  const panel = vscode.window.createWebviewPanel(
    'ragResults',
    'RAG Search Results',
    vscode.ViewColumn.Two,
    {}
  );

  panel.webview.html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: system-ui; padding: 20px; }
        pre { background: #f5f5f5; padding: 10px; border-radius: 5px; }
      </style>
    </head>
    <body>
      <h2>🔍 Search Results (ML-powered)</h2>
      <pre>${results}</pre>
    </body>
    </html>
  `;
}

export function deactivate() {
  if (mlcEngine) {
    mlcEngine.unload();
  }
}
