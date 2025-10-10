# Contributing to ZFS Datadog Integration

Thank you for your interest in contributing! This guide will help you get started.

## Ways to Contribute

### 1. Testing on Different Operating Systems

The integration needs testing on various platforms. See open issues for specific needs:

- **BSD Systems** ([#1](https://github.com/ryanmaclean/zfs-datadog-integration/issues/1), [#6](https://github.com/ryanmaclean/zfs-datadog-integration/issues/6)) - FreeBSD, OpenBSD, NetBSD
- **TrueNAS** ([#2](https://github.com/ryanmaclean/zfs-datadog-integration/issues/2), [#3](https://github.com/ryanmaclean/zfs-datadog-integration/issues/3)) - SCALE and CORE
- **RHEL Family** ([#8](https://github.com/ryanmaclean/zfs-datadog-integration/issues/8)) - Rocky, AlmaLinux, RHEL
- **Illumos** ([#7](https://github.com/ryanmaclean/zfs-datadog-integration/issues/7)) - OpenIndiana

**How to Help:**
1. Install on your platform following [INSTALL.md](INSTALL.md)
2. Test all event types (scrub, resilver, state changes)
3. Report results in the relevant issue
4. Document any platform-specific quirks

### 2. Error Injection Testing

Issue [#4](https://github.com/ryanmaclean/zfs-datadog-integration/issues/4) needs testing of checksum and I/O error handling.

**Requirements:**
- Compile zinject using `scripts/compile-zinject.sh`
- Run error injection tests
- Verify events reach Datadog
- Document results

### 3. Improving Packer Templates

Issue [#5](https://github.com/ryanmaclean/zfs-datadog-integration/issues/5) tracks Packer automation issues.

**Help Needed:**
- Debug QEMU configuration
- Test builds on different architectures
- Improve template reliability

### 4. Documentation Improvements

- Fix typos or unclear instructions
- Add platform-specific notes
- Improve troubleshooting guides
- Add examples and use cases

### 5. Code Contributions

- Bug fixes
- New features
- Performance improvements
- Additional event types

## Development Setup

### Prerequisites

```bash
# Clone the repository
git clone https://github.com/ryanmaclean/zfs-datadog-integration.git
cd zfs-datadog-integration

# Install development dependencies
# Linux (Ubuntu/Debian)
sudo apt install shellcheck

# macOS
brew install shellcheck
```

### Testing Your Changes

```bash
# Syntax check all scripts
shellcheck scripts/*.sh

# POSIX compliance check
for script in scripts/*.sh; do
  sh -n "$script"
done

# Test with mock Datadog server
python3 mock-datadog-server.py &
# Configure to use localhost
export DD_API_URL="http://localhost:8080"
# Run your tests
```

## Pull Request Process

1. **Fork the repository**

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow existing code style
   - Use POSIX-compatible shell syntax (#!/bin/sh)
   - Add comments for complex logic
   - Keep scripts minimal and focused

4. **Test thoroughly**
   - Run shellcheck on modified scripts
   - Test on your target platform
   - Verify events reach Datadog

5. **Commit with clear messages**
   ```bash
   git commit -m "Add feature: brief description

   Detailed explanation of what changed and why.
   
   Closes #123"
   ```

6. **Push and create PR**
   ```bash
   git push origin feature/your-feature-name
   ```
   - Open PR on GitHub
   - Reference related issues
   - Describe testing performed

7. **Respond to review feedback**

## Code Style Guidelines

### Shell Scripts

- Use `#!/bin/sh` (POSIX), not `#!/bin/bash`
- Use `[ ]` not `[[ ]]`
- Use `printf` not `echo -e`
- Avoid bashisms (check with shellcheck)
- Quote variables: `"$var"` not `$var`
- Use descriptive variable names
- Add error checking

### Good Example

```sh
#!/bin/sh
# Description of what this does

set -e  # Exit on error

ZED_DIR="$(dirname "$0")"
. "${ZED_DIR}/zfs-datadog-lib.sh" || exit 1

EVENT_TYPE="my_event"
TITLE="Event Title: ${ZEVENT_POOL}"

if [ -z "$ZEVENT_POOL" ]; then
    printf "Error: ZEVENT_POOL not set\n" >&2
    exit 1
fi

send_datadog_event "$TITLE" "$TEXT" "$ALERT_TYPE" "$PRIORITY" "$EVENT_TYPE"
exit 0
```

### Bad Example

```bash
#!/bin/bash  # Should be /bin/sh
source lib.sh  # Should be `. lib.sh`

EVENT_TYPE=my_event  # Should quote
echo -e "Title: $ZEVENT_POOL"  # Should use printf

[[ -z $var ]]  # Should use [ ]
```

## Documentation Guidelines

- Use Markdown format
- Include code examples
- Test all commands
- Add troubleshooting sections
- Keep language clear and concise
- Link to related docs

## Reporting Bugs

### Before Reporting

1. Check existing issues
2. Run `scripts/validate-config.sh`
3. Check logs (journalctl -u zfs-zed or /var/log/zed.log)
4. Test on a clean system if possible

### Bug Report Template

```markdown
**Description**
Clear description of the bug

**Environment**
- OS: Ubuntu 24.04
- ZFS Version: 2.2.0
- Datadog Agent: 7.71.0

**Steps to Reproduce**
1. Install integration
2. Run zpool scrub
3. No event appears

**Expected Behavior**
Event should appear in Datadog

**Actual Behavior**
No event received

**Logs**
```
# Paste relevant logs
```

**Additional Context**
Any other relevant information
```

## Feature Requests

Use the GitHub issue template to request features:
- Describe the use case
- Explain why it's valuable
- Suggest implementation if possible
- Link to related work

## Testing Platforms

We especially need testers with access to:

- **FreeBSD** 13.0+ with native ZFS
- **TrueNAS SCALE** (latest stable)
- **TrueNAS CORE** (latest stable)
- **OpenBSD** with ZFS
- **NetBSD** with ZFS
- **OpenIndiana** Hipster
- **Rocky Linux** 8/9
- **AlmaLinux** 8/9

## Community

- **Issues**: [GitHub Issues](https://github.com/ryanmaclean/zfs-datadog-integration/issues)
- **Discussions**: Use GitHub Discussions for questions
- **Security**: Report security issues privately to the maintainer

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn
- No harassment or discrimination

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions?

Open an issue with the `question` label or start a discussion on GitHub.

## Thank You!

Every contribution helps make this project better for the ZFS community. 🎉
