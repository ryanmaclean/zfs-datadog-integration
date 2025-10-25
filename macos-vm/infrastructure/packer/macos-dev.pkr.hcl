# Packer template for macOS development VM with code-server
# Uses Tart builder for Apple Silicon

packer {
  required_plugins {
    tart = {
      version = ">= 1.2.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "vm_name" {
  type    = string
  default = "macos-dev"
}

variable "base_image" {
  type    = string
  default = "ghcr.io/cirruslabs/macos-ventura-base:latest"
}

variable "cpu_count" {
  type    = number
  default = 4
}

variable "memory_gb" {
  type    = number
  default = 8
}

variable "disk_size_gb" {
  type    = number
  default = 50
}

variable "code_server_password" {
  type    = string
  default = "dev-2025"
  sensitive = true
}

source "tart-cli" "macos" {
  vm_base_name = var.base_image
  vm_name      = var.vm_name
  cpu_count    = var.cpu_count
  memory_gb    = var.memory_gb
  disk_size_gb = var.disk_size_gb
  
  ssh_username = "admin"
  ssh_password = "admin"
  ssh_timeout  = "120s"
}

build {
  sources = ["source.tart-cli.macos"]

  # Update system
  provisioner "shell" {
    inline = [
      "echo 'Updating system...'",
      "sudo softwareupdate --install --all --agree-to-license || true"
    ]
  }

  # Install Homebrew
  provisioner "shell" {
    inline = [
      "echo 'Installing Homebrew...'",
      "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
      "echo 'eval \"$(/opt/homebrew/bin/brew shellenv)\"' >> ~/.zprofile",
      "eval \"$(/opt/homebrew/bin/brew shellenv)\""
    ]
  }

  # Install development tools
  provisioner "shell" {
    inline = [
      "echo 'Installing development tools...'",
      "brew install git node python3 go rust",
      "brew install --cask visual-studio-code"
    ]
  }

  # Install code-server
  provisioner "shell" {
    inline = [
      "echo 'Installing code-server...'",
      "brew install code-server"
    ]
  }

  # Configure code-server
  provisioner "shell" {
    inline = [
      "echo 'Configuring code-server...'",
      "mkdir -p ~/.config/code-server",
      "cat > ~/.config/code-server/config.yaml <<EOF",
      "bind-addr: 0.0.0.0:8080",
      "auth: password",
      "password: ${var.code_server_password}",
      "cert: false",
      "EOF"
    ]
  }

  # Create code-server launch agent
  provisioner "shell" {
    inline = [
      "echo 'Creating code-server launch agent...'",
      "mkdir -p ~/Library/LaunchAgents",
      "cat > ~/Library/LaunchAgents/com.coder.code-server.plist <<EOF",
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
      "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
      "<plist version=\"1.0\">",
      "<dict>",
      "  <key>Label</key>",
      "  <string>com.coder.code-server</string>",
      "  <key>ProgramArguments</key>",
      "  <array>",
      "    <string>/opt/homebrew/bin/code-server</string>",
      "  </array>",
      "  <key>RunAtLoad</key>",
      "  <true/>",
      "  <key>KeepAlive</key>",
      "  <true/>",
      "  <key>StandardOutPath</key>",
      "  <string>/tmp/code-server.log</string>",
      "  <key>StandardErrorPath</key>",
      "  <string>/tmp/code-server.error.log</string>",
      "</dict>",
      "</plist>",
      "EOF",
      "launchctl load ~/Library/LaunchAgents/com.coder.code-server.plist"
    ]
  }

  # Install ML Code Assistant extension
  provisioner "file" {
    source      = "../../code-app-ml-extension"
    destination = "/tmp/mlcode-extension"
  }

  provisioner "shell" {
    inline = [
      "echo 'Installing ML Code Assistant...'",
      "mkdir -p ~/.local/share/code-server/extensions",
      "cp -r /tmp/mlcode-extension ~/.local/share/code-server/extensions/mlcode-extension",
      "cd ~/.local/share/code-server/extensions/mlcode-extension",
      "npm install"
    ]
  }

  # Clean up
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up...'",
      "rm -rf /tmp/mlcode-extension",
      "brew cleanup"
    ]
  }

  # Final message
  provisioner "shell" {
    inline = [
      "echo '✅ macOS development VM ready!'",
      "echo 'code-server running on port 8080'",
      "echo 'Password: ${var.code_server_password}'"
    ]
  }

  post-processor "manifest" {
    output = "manifest.json"
  }
}
