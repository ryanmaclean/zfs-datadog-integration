# Packer Best Practices Applied

## Linting and Validation

### `packer fmt`
Formats HCL files to canonical style:
- Consistent indentation
- Proper spacing
- Alphabetical ordering of attributes

### `packer validate`
Validates template syntax and configuration:
- Required fields present
- Valid variable references
- Plugin compatibility
- SSH/WinRM configuration

## Best Practices Implemented

### 1. **Separate Cloud-Init Files**
```hcl
cd_files = ["http/user-data", "http/meta-data"]
cd_label = "cidata"
```
✅ Proper cloud-init for Ubuntu/Debian/Arch

### 2. **Headless Builds**
```hcl
headless = true
```
✅ No GUI, faster builds, CI/CD compatible

### 3. **Timeouts**
```hcl
ssh_timeout = "30m"
```
✅ Generous timeouts for slow cloud-init

### 4. **Environment Variables**
```hcl
variable "dd_api_key" {
  default = env("DD_API_KEY")
}
```
✅ Secure API key handling

### 5. **Parallel Builds**
Running all 9 OSes simultaneously
✅ Efficient resource usage

### 6. **Output Organization**
```hcl
output_directory = "output-{os}-zfs"
```
✅ Clear separation of artifacts

### 7. **Provisioner Ordering**
1. Install packages
2. Install Datadog Agent
3. Copy files
4. Configure permissions
5. Cleanup

✅ Logical, repeatable order

## Issues Found and Fixed

### ❌ Template Variable Escaping
**Problem**: `$(rpm --eval '%{dist}')`
**Fix**: Hardcode versions or use `$$(...)`

### ❌ Missing Cloud-Init
**Problem**: Cloud images timeout on SSH
**Fix**: Add `cd_files` with user-data

### ❌ ISO URLs
**Problem**: 404 errors on old ISOs
**Fix**: Update to latest versions

## Datadog on BSD

### FreeBSD
```bash
pkg install datadog-agent
sysrc datadog_enable="YES"
service datadog start
```

### OpenBSD
```bash
pkg_add datadog-agent
rcctl enable datadog
rcctl start datadog
```

### NetBSD
```bash
pkgin install datadog-agent
# Manual service setup required
```

**Note**: Datadog Agent has limited BSD support. Alternative: Use HTTP API directly (current implementation).

## Recommended Tools

1. **packer fmt** - Auto-format all templates
2. **packer validate** - Syntax checking
3. **packer inspect** - View template details
4. **tflint** - Additional HCL linting
5. **pre-commit hooks** - Automated validation

## Current Status

✅ All templates formatted
✅ All templates validated
✅ Best practices applied
✅ Builds running successfully
