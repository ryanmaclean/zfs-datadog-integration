# 📱 Code App Setup for iOS

**Code App** is VS Code for iOS with full plugin support!

## 🚀 Quick Start

### **1. Install Code App**
```
App Store → Search "Code App" → Install (Free)
```

### **2. Clone This Repo**
```
Code App → Clone Repository
URL: https://github.com/your-username/windsurf-project
Location: iCloud Drive (auto-syncs to Mac!)
```

### **3. Open in Code App**
```
Files App → iCloud Drive → windsurf-project
Share → Code App
```

---

## ⚙️ Configuration

### **Tasks Already Configured**
Press `Cmd+Shift+P` (or tap ⌘ on iPad keyboard) → "Run Task":

- 🚀 **Build ARM64 Kernel** - Start kernel build
- 📋 **List VMs** - Show running VMs
- ▶️ **Start Kernel Build VM** - Start the VM
- ⏹️ **Stop Kernel Build VM** - Stop the VM
- 🔍 **Check VM Disk Space** - See available space
- 📊 **Check Build Progress** - Monitor build log
- 💾 **Check Remote Storage** - tank3 usage
- 🧪 **Run ZFS Tests** - Test ZFS operations

### **Extensions Installed**
Code App will prompt to install:
- ✅ ShellCheck (bash linting)
- ✅ Shell Format (auto-format)
- ✅ Bash IDE (autocomplete)
- ✅ Remote-SSH (connect to Mac)
- ✅ GitLens (git superpowers)
- ✅ Error Lens (inline errors)
- ✅ Spell Checker

---

## 🔌 Plugin System

### **How It Works**
Code App uses the **VS Code Extension API**:

```javascript
// Extensions run in WebView
// Full VS Code compatibility
// Can execute shell commands
// Access filesystem via API
```

### **Custom Plugin Example**
```javascript
// .vscode/my-plugin.js
const vscode = require('vscode');

function activate(context) {
  let disposable = vscode.commands.registerCommand(
    'extension.buildKernel',
    function () {
      const terminal = vscode.window.createTerminal('Build');
      terminal.sendText('bash scripts/build-arm64-kernel-now.sh');
      terminal.show();
    }
  );
  context.subscriptions.push(disposable);
}

exports.activate = activate;
```

---

## 📁 iCloud Sync

### **How It Works**
```
iPad: Edit in Code App
  ↓ (iCloud auto-sync)
Mac: Files appear in ~/Library/Mobile Documents/
  ↓
Mac: VMs can access files
  ↓
iPad: See changes instantly
```

### **Setup iCloud Sync**
```bash
# On Mac - symlink to iCloud
ln -s ~/Library/Mobile\ Documents/com~apple~CloudDocs/windsurf-project \
      ~/CascadeProjects/windsurf-project

# Now edits on iPad appear on Mac instantly!
```

---

## 🖥️ Remote Development

### **SSH to Mac**
```json
// .vscode/settings.json (already configured)
{
  "remote.SSH.remotePlatform": {
    "your-mac-ip": "darwin"
  }
}
```

### **Connect**
```
1. Cmd+Shift+P → "Remote-SSH: Connect to Host"
2. Enter: studio@your-mac-ip
3. Full Mac filesystem access!
4. Run builds directly on Mac
```

---

## 🎯 Workflows

### **Workflow 1: Edit on iPad, Build on Mac**
```
1. Edit script in Code App (iPad)
2. Save → Auto-syncs to Mac via iCloud
3. Tap "Run Task" → "Build ARM64 Kernel"
4. Code App executes on Mac via SSH
5. See output in integrated terminal
```

### **Workflow 2: Full Remote Development**
```
1. Code App → Connect to Mac via SSH
2. Open ~/CascadeProjects/windsurf-project
3. Edit files directly on Mac
4. Run tasks on Mac
5. No sync needed - working directly on Mac!
```

### **Workflow 3: Offline Editing**
```
1. Edit files in Code App (offline)
2. Git commits work offline
3. When online → iCloud syncs
4. Push to GitHub
```

---

## 🔧 Advanced Features

### **Custom Keybindings**
```json
// .vscode/keybindings.json
[
  {
    "key": "cmd+shift+b",
    "command": "workbench.action.tasks.runTask",
    "args": "🚀 Build ARM64 Kernel"
  },
  {
    "key": "cmd+shift+l",
    "command": "workbench.action.tasks.runTask",
    "args": "📋 List VMs"
  }
]
```

### **Snippets**
```json
// .vscode/bash.code-snippets
{
  "Lima Shell": {
    "prefix": "lima",
    "body": [
      "limactl shell ${1:vm-name} -- ${2:command}"
    ]
  },
  "ZFS Create": {
    "prefix": "zfscreate",
    "body": [
      "sudo zfs create ${1:pool}/${2:dataset}"
    ]
  }
}
```

---

## 💡 Tips

### **Performance**
- ✅ Code App is native (fast!)
- ✅ Syntax highlighting works offline
- ✅ Git operations are instant
- ✅ Terminal is fully functional

### **Limitations**
- ⚠️ Can't run VMs on iOS (use SSH to Mac)
- ⚠️ Can't compile kernels on iOS (use SSH to Mac)
- ✅ Everything else works!

### **Best Practices**
1. Use iCloud for file sync
2. Use SSH for heavy operations
3. Use tasks for common commands
4. Use snippets for repetitive code

---

## 🎨 Customization

### **Themes**
```
Settings → Color Theme → Choose your favorite
```

### **Font**
```json
{
  "editor.fontFamily": "SF Mono, Menlo, Monaco",
  "editor.fontSize": 14,
  "editor.lineHeight": 1.6
}
```

### **Layout**
```
- Split editors (side by side)
- Integrated terminal (bottom)
- File explorer (left)
- Git panel (left)
```

---

## 🚀 You're Ready!

**Code App gives you**:
- ✅ Full VS Code on iOS
- ✅ Plugin support
- ✅ iCloud sync
- ✅ SSH to Mac
- ✅ Git integration
- ✅ Terminal
- ✅ Tasks automation

**Just install Code App and open this project!** 📱✨
