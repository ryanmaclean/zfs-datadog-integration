import { useState, useEffect } from 'react';
import { invoke } from '@tauri-apps/api/tauri';
import Editor from '@monaco-editor/react';
import './App.css';

function App() {
  const [files, setFiles] = useState<string[]>([]);
  const [currentFile, setCurrentFile] = useState<string>('');
  const [content, setContent] = useState<string>('');
  const [macIp, setMacIp] = useState<string>('192.168.1.100');
  const [connected, setConnected] = useState<boolean>(false);
  const [output, setOutput] = useState<string>('');

  // Load files from iCloud
  useEffect(() => {
    loadFiles();
  }, []);

  async function loadFiles() {
    try {
      const fileList = await invoke<string[]>('list_icloud_files');
      setFiles(fileList);
    } catch (error) {
      console.error('Failed to load files:', error);
    }
  }

  async function loadFile(filename: string) {
    try {
      const fileContent = await invoke<string>('load_from_icloud', { filename });
      setContent(fileContent);
      setCurrentFile(filename);
    } catch (error) {
      console.error('Failed to load file:', error);
    }
  }

  async function saveFile() {
    if (!currentFile) {
      alert('No file selected');
      return;
    }

    try {
      const result = await invoke<string>('save_to_icloud', {
        filename: currentFile,
        content: content
      });
      alert(result);
    } catch (error) {
      alert(`Failed to save: ${error}`);
    }
  }

  async function connectToMac() {
    try {
      const url = await invoke<string>('connect_to_mac', {
        macIp: macIp,
        port: 8080
      });
      setConnected(true);
      alert(`Connected to code-server at ${url}`);
      // Open in iframe or new window
      window.open(url, '_blank');
    } catch (error) {
      alert(`Connection failed: ${error}`);
    }
  }

  async function runCommand(command: string) {
    try {
      const result = await invoke<string>('run_ssh_command', {
        macIp: macIp,
        command: command
      });
      setOutput(result);
    } catch (error) {
      setOutput(`Error: ${error}`);
    }
  }

  return (
    <div className="container">
      <div className="sidebar">
        <h2>Files (iCloud)</h2>
        <ul>
          {files.map(file => (
            <li key={file} onClick={() => loadFile(file)}>
              {file}
            </li>
          ))}
        </ul>
        
        <h2>Mac Connection</h2>
        <input
          type="text"
          value={macIp}
          onChange={(e) => setMacIp(e.target.value)}
          placeholder="Mac IP"
        />
        <button onClick={connectToMac}>
          {connected ? '✅ Connected' : 'Connect to Mac'}
        </button>
        
        <h2>Quick Commands</h2>
        <button onClick={() => runCommand('limactl list')}>
          List VMs
        </button>
        <button onClick={() => runCommand('limactl start kernel-build')}>
          Start Build VM
        </button>
        <button onClick={() => runCommand('df -h')}>
          Check Disk
        </button>
      </div>

      <div className="main">
        <div className="toolbar">
          <span>{currentFile || 'No file selected'}</span>
          <button onClick={saveFile}>💾 Save to iCloud</button>
        </div>

        <Editor
          height="60vh"
          defaultLanguage="bash"
          theme="vs-dark"
          value={content}
          onChange={(value) => setContent(value || '')}
          options={{
            minimap: { enabled: false },
            fontSize: 14,
            wordWrap: 'on'
          }}
        />

        <div className="output">
          <h3>Command Output</h3>
          <pre>{output}</pre>
        </div>
      </div>
    </div>
  );
}

export default App;
