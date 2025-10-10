packer {
  required_plugins {
      version = ">= 1.0.0"
    }
  }
}

# Add to all builds:
build {
  # ... existing provisioners ...

    api_key = var.dd_api_key

    # Send build metrics
    metrics {
      enabled = true
      prefix  = "packer.zfs"
    }

    # Send build logs
    logs {
      enabled = true
      source  = "packer"
      service = "zfs-build"
      tags    = ["os:${source.name}", "env:test"]
    }
  }
}
