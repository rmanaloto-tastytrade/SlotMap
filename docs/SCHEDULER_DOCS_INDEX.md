# Scheduler Documentation Index

## Overview

This index provides a comprehensive guide to all scheduler-related documentation for the SlotMap project's automatic tool update system.

## Documentation Hierarchy

```
📚 Scheduler Documentation
│
├── 📖 Research & Analysis
│   ├── SCHEDULER_RESEARCH.md ← Start here for background
│   └── DECISION_MODERN_SCHEDULERS.md ← Why we chose this approach
│
├── 🔧 Technical Implementation
│   ├── SCHEDULER_IMPLEMENTATION.md ← Technical details
│   └── AUTO_UPDATE_SETUP.md ← User setup guide
│
├── 💻 Code & Configuration
│   ├── scripts/schedulers/README.md ← Scripts documentation
│   ├── scripts/schedulers/*.plist ← macOS configs
│   └── scripts/schedulers/*.service/timer ← Linux configs
│
└── 📋 Project Integration
    └── PROJECT_PLAN.md ← Phase 0.5: Tool Auto-Update Infrastructure
```

## Reading Order for New Contributors

### 1. Understanding the Decision
1. **[SCHEDULER_RESEARCH.md](SCHEDULER_RESEARCH.md)** - Why modern schedulers?
   - Historical context of cron limitations
   - Modern scheduler advantages
   - Industry best practices
   - 39 academic and industry citations

2. **[DECISION_MODERN_SCHEDULERS.md](DECISION_MODERN_SCHEDULERS.md)** - Our specific choice
   - Architectural Decision Record (ADR-001)
   - Quantitative comparison
   - Cost-benefit analysis
   - Risk assessment

### 2. Technical Implementation
3. **[SCHEDULER_IMPLEMENTATION.md](SCHEDULER_IMPLEMENTATION.md)** - How it works
   - Architecture diagrams
   - Platform-specific details
   - Security analysis
   - Performance optimization

### 3. Practical Setup
4. **[AUTO_UPDATE_SETUP.md](AUTO_UPDATE_SETUP.md)** - How to use it
   - Quick setup instructions
   - Platform-specific guides
   - Troubleshooting tips
   - Monitoring commands

5. **[scripts/schedulers/README.md](../scripts/schedulers/README.md)** - Script details
   - File descriptions
   - Management commands
   - Security notes

## Quick Reference

### For Users
- **Setup**: [AUTO_UPDATE_SETUP.md](AUTO_UPDATE_SETUP.md)
- **One-command install**: `./scripts/schedulers/install_scheduler.sh`

### For Developers
- **Technical details**: [SCHEDULER_IMPLEMENTATION.md](SCHEDULER_IMPLEMENTATION.md)
- **Code location**: `/scripts/schedulers/`

### For Decision Makers
- **Research**: [SCHEDULER_RESEARCH.md](SCHEDULER_RESEARCH.md)
- **Decision**: [DECISION_MODERN_SCHEDULERS.md](DECISION_MODERN_SCHEDULERS.md)

## Document Purposes

| Document | Purpose | Audience | Length |
|----------|---------|----------|--------|
| SCHEDULER_RESEARCH.md | Academic research with citations | Technical leads, architects | ~15 pages |
| DECISION_MODERN_SCHEDULERS.md | Formal ADR for the decision | All stakeholders | ~8 pages |
| SCHEDULER_IMPLEMENTATION.md | Technical implementation guide | Developers | ~12 pages |
| AUTO_UPDATE_SETUP.md | User setup instructions | All users | ~5 pages |
| schedulers/README.md | Script documentation | Developers, DevOps | ~3 pages |

## Key Concepts

### Modern Schedulers
- **launchd**: Apple's system and service manager (macOS)
- **systemd**: Modern Linux init and service manager
- **crontab**: Legacy Unix scheduler (deprecated)

### Our Implementation
- Platform detection (macOS vs Linux)
- User-level installation (no sudo)
- Automatic tool updates (gh, devcontainer)
- Modern logging and monitoring

### Benefits Over Crontab
1. ✅ Automatic restart on failure
2. ✅ Native logging integration
3. ✅ Power management awareness
4. ✅ Security sandboxing
5. ✅ Dependency management
6. ✅ Persistent timers (run missed jobs)

## Common Tasks

### Install Scheduler
```bash
./scripts/schedulers/install_scheduler.sh
```

### Check Status
```bash
# macOS
launchctl list | grep slotmap

# Linux
systemctl --user status slotmap-toolupdate.timer
```

### View Logs
```bash
# macOS
tail -f /tmp/slotmap-toolupdate.log

# Linux
journalctl --user -u slotmap-toolupdate -f
```

### Run Manually
```bash
# macOS
launchctl start com.slotmap.toolupdate

# Linux
systemctl --user start slotmap-toolupdate.service
```

## Related Documentation

### Project Context
- [PROJECT_PLAN.md](../PROJECT_PLAN.md) - Phase 0.5: Tool Auto-Update Infrastructure
- [DO_NOT_MODIFY.md](../DO_NOT_MODIFY.md) - System file modification restrictions

### Security & SSH
- [SSH_KEY_SAFETY_AUDIT.md](SSH_KEY_SAFETY_AUDIT.md) - SSH security measures
- [DYNAMIC_USERNAME_RESOLUTION.md](DYNAMIC_USERNAME_RESOLUTION.md) - Username handling

## FAQ

### Why not use crontab?
See [SCHEDULER_RESEARCH.md](SCHEDULER_RESEARCH.md) for detailed analysis. Summary: crontab is deprecated on macOS and lacks modern features like automatic restart, proper logging, and security sandboxing.

### Do I need sudo?
No! Everything installs to user directories. This is by design for security.

### Will this work on my system?
- macOS 10.4+ ✅ (launchd)
- Linux with systemd ✅ (Ubuntu 15.04+, Debian 8+, RHEL 7+)
- Legacy Linux ⚠️ (manual cron setup required)

### How do I disable it?
```bash
# macOS
launchctl unload ~/Library/LaunchAgents/com.slotmap.toolupdate.plist

# Linux
systemctl --user disable slotmap-toolupdate.timer
```

## Maintenance

### Document Owners
- Research: Architecture Team
- Implementation: Development Team
- User Guides: DevOps Team

### Review Schedule
- Quarterly review of effectiveness
- Annual review of technology choices
- Ad-hoc updates for OS changes

### Version History
- v1.0.0 (2024-11-23): Initial implementation
- Future: Webhook integration planned

## Contributing

### Adding Documentation
1. Follow existing document structure
2. Include citations for claims
3. Update this index
4. Submit PR with review

### Updating Implementation
1. Update code in `/scripts/schedulers/`
2. Update technical documentation
3. Update user guides
4. Test on both platforms

## Contact

For questions or issues:
- GitHub Issues: [SlotMap Repository](https://github.com/rmanaloto-tastytrade/SlotMap)
- Documentation: This index
- Technical: See implementation guide

---

*Last Updated: November 23, 2024*
*Version: 1.0.0*