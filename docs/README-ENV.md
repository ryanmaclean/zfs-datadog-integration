# Environment Configuration

## Using .env.local for Datadog API Key

For security, store your Datadog API key in `.env.local` instead of hardcoding it.

### Setup

1. **Copy the example file:**
   ```bash
   cp .env.local.example .env.local
   ```

2. **Edit .env.local with your real API key:**
   ```bash
   vi .env.local
   ```

3. **Set your Datadog API key:**
   ```bash
   DD_API_KEY="your_actual_api_key_here"
   ```

4. **The file is automatically gitignored** - your secrets won't be committed

### How It Works

The `config.sh` file automatically sources `.env.local` if it exists:

```sh
# In config.sh
if [ -f "$(dirname "$0")/.env.local" ]; then
    . "$(dirname "$0")/.env.local"
fi
```

### For Production

On production systems, you can either:

**Option 1: Use .env.local in ZED directory**
```bash
sudo cp .env.local /etc/zfs/zed.d/.env.local
sudo chmod 600 /etc/zfs/zed.d/.env.local
```

**Option 2: Edit config.sh directly**
```bash
sudo vi /etc/zfs/zed.d/config.sh
# Set DD_API_KEY directly
```

**Option 3: Use environment variables**
```bash
# In /etc/environment or systemd service file
DD_API_KEY=your_key_here
```

### Security Best Practices

1. **Never commit .env.local** - It's in .gitignore
2. **Set restrictive permissions:**
   ```bash
   chmod 600 .env.local
   ```
3. **Use different keys for dev/staging/prod**
4. **Rotate keys regularly**
5. **Use Datadog's key management features**

### Get Your API Key

1. Go to https://app.datadoghq.com/organization-settings/api-keys
2. Create a new API key or copy an existing one
3. Paste it into `.env.local`

### Example .env.local

```bash
# Datadog Configuration
DD_API_KEY="your_actual_key_here"
DD_SITE="datadoghq.com"
DD_API_URL="https://api.datadoghq.com"
DOGSTATSD_HOST="localhost"
DOGSTATSD_PORT="8125"
DD_TAGS="env:production,service:zfs-monitoring,host:my-server"
```

### Testing

Test your configuration:
```bash
# Source the env file
. .env.local

# Check it's loaded
echo $DD_API_KEY

# Run a test
./test-mock-datadog.sh
```

### Troubleshooting

**API key not loading:**
- Check file permissions: `ls -la .env.local`
- Verify file location: `pwd`
- Check for syntax errors: `sh -n .env.local`

**Still using test key:**
- Make sure you edited `.env.local`, not `.env.local.example`
- Restart ZED after changes: `sudo systemctl restart zfs-zed`
