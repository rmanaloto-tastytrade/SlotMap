# Local Environment Configuration

This directory contains local environment configuration files that are **gitignored**.

## Setup

Copy the example file and customize for your environment:

```bash
cp devcontainer.env.example devcontainer.env
# Edit devcontainer.env with your values
```

## Files

| File | Purpose |
|------|---------|
| `devcontainer.env.example` | Template with all available options (committed to git) |
| `devcontainer.env` | Your local configuration (gitignored, never committed) |

## Available Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DEVCONTAINER_REMOTE_HOST` | Remote host for deployment | (required) |
| `DEVCONTAINER_REMOTE_USER` | SSH username on remote host | Current user |
| `DEVCONTAINER_SSH_PORT` | Container SSH port on remote host | 9222 |
| `DEVCONTAINER_WORKSPACE_PATH` | Workspace path on remote host | ~/dev/devcontainers/workspace |

## Security Notes

- **Never commit `devcontainer.env`** - it contains host-specific information
- The `.gitignore` file explicitly excludes `config/env/*.env` files
- Only `.example` files are tracked in git
