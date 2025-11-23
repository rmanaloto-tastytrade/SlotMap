# CRITICAL INSTRUCTIONS - READ BEFORE ANY FILE OPERATIONS

## FORBIDDEN ACTIONS - DO NOT MODIFY

### 1. SSH Configuration Files
- **DO NOT MODIFY** `~/.ssh/config` on Mac or remote hosts
- **DO NOT MODIFY** `~/.ssh/known_hosts`
- **DO NOT MODIFY** any SSH keys (`~/.ssh/id_*`, `~/.ssh/*_key`)
- SSH access works with existing configurations using SSH keys
- No username needs to be specified - just use `ssh c0802s4.ny5`

### 2. System Configuration Files
- **DO NOT MODIFY** any files outside the project directory
- **DO NOT MODIFY** `/etc/*` files
- **DO NOT MODIFY** user home directory configs (`.bashrc`, `.profile`, etc.)

### 3. Git Global Configuration
- **DO NOT MODIFY** global git config (`~/.gitconfig`)
- Only modify project-specific git config if absolutely necessary

## ALLOWED ACTIONS

### 1. Project Files Only
- Modify files ONLY within `/Users/ray.manaloto@tastytrade.com/dev/github/SergeyMakeev/SlotMap-security-test/`
- Create new files only in the project directory
- Use project-specific git config (`git config` without `--global`)

### 2. Remote Operations
- Use existing SSH access: `ssh c0802s4.ny5`
- Clone repositories to appropriate directories on remote
- Run commands on remote without modifying remote configs

## VERIFICATION BEFORE MODIFICATIONS

Before modifying ANY file:
1. Check if file is in project directory
2. Check if file is in the FORBIDDEN list above
3. If uncertain, ASK before modifying

## SSH ACCESS INFORMATION

- **Remote host**: c0802s4.ny5 (resolves to c0802s4.ny5.tastyworks.com)
- **SSH command**: `ssh c0802s4.ny5` (no username needed - uses SSH keys)
- **Remote user**: rmanaloto (determined by SSH config)
- **Agent forwarding**: Use `ssh -A c0802s4.ny5` when needed

## PROJECT CONTEXT

This is the SlotMap-security-test directory, NOT the main SlotMap directory.
Current branch: security-fixes-phase1
Remote repository: This is a fork/test repository for security fixes

## ENFORCEMENT

This file MUST be read before any file modification operations.
If you violate these rules, the user will lose trust in your assistance.