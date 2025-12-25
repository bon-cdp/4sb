# 4sb.io Architecture

## Vision
A mobile-first cloud terminal that gives anyone with a phone the same development power as someone with a $3,000 MacBook. No strings attached.

## Core Philosophy: Anti-Slop
- Zero bloat, maximum utility
- Plain terminal, no forced workflows
- Users do whatever they want - shop, code, deploy, AI assist

---

## System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        4sb.io Landing                           │
│                    (Johnny's Domain - Svelte)                   │
│         Beautiful landing page + Auth + Docs                    │
└─────────────────────────┬───────────────────────────────────────┘
                          │ Magic Link / OAuth
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Cloud Run Dispatcher                        │
│              Assigns user to warm VM from pool                   │
│                    Returns WebSocket URL                         │
└─────────────────────────┬───────────────────────────────────────┘
                          │ wss://vm-xx.4sb.io/shell
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                   C++ Terminal Bridge (Crow)                     │
│    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│    │  WebSocket  │──│   forkpty   │──│  /bin/bash  │           │
│    │   Handler   │  │   Bridge    │  │   Session   │           │
│    └─────────────┘  └─────────────┘  └─────────────┘           │
│                                                                  │
│    Pre-installed: git, python3, gcc, qwen-code, claude-code     │
└─────────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Cloud Filestore (NFS)                          │
│              /users/{username} - Persistent $HOME                │
└─────────────────────────────────────────────────────────────────┘
```

---

## GCloud Infrastructure

### Compute Engine - Terminal VMs
- **Instance Type**: `t2a-standard-1` (ARM, cheap + fast)
- **Image**: Custom with C++ bridge pre-built
- **Managed Instance Group**: 5-10 warm instances in pool
- **Region**: Start with `us-central1`, expand to edge later

### Cloud Run - Dispatcher
- Handles auth validation
- Assigns VMs from Redis pool
- Stateless, scales to zero

### Memorystore (Redis)
- Tracks VM states: `WARM`, `ASSIGNED`, `CLEANING`
- User session mapping
- Sub-millisecond lookups

### Cloud Filestore
- Shared NFS for user home directories
- Persistent across VM assignments
- Mounted on-demand when user connects

---

## The C++ Bridge

**Why C++?**
- 15MB RAM per connection vs 150MB for Node.js
- Direct PTY access, no abstraction layers
- Handles 1000s of concurrent terminals on a single instance

**Stack:**
- Framework: Crow (lightweight, header-only)
- WebSocket: Built into Crow
- PTY: Native Linux `forkpty()`
- Auth: JWT validation

---

## Directory Structure

```
4sb/
├── bridge/                 # C++ Terminal Bridge
│   ├── src/
│   │   └── main.cpp       # WebSocket + PTY bridge
│   ├── include/
│   │   └── crow_all.h     # Crow framework (single header)
│   ├── CMakeLists.txt
│   └── Dockerfile
├── infra/                  # GCloud Infrastructure
│   ├── scripts/
│   │   ├── setup-project.sh
│   │   ├── create-vm-template.sh
│   │   ├── pool-manager.sh
│   │   └── deploy.sh
│   └── templates/
│       └── startup-script.sh
├── frontend/               # Johnny's playground
│   └── (Svelte app - landing, auth, docs)
├── docs/
│   └── JOHNNY-HANDOFF.md  # Frontend integration guide
└── ARCHITECTURE.md
```

---

## Auth Flow

1. User hits landing page (Johnny's beautiful Svelte)
2. Enters email → receives magic link
3. Clicks link → frontend validates token
4. Frontend calls `/assign-instance` API
5. Dispatcher returns `wss://vm-xx.4sb.io/shell?token=xyz`
6. Frontend opens xterm.js, connects to WebSocket
7. User is in their terminal. Done.

---

## What Users Get

A real Linux shell with:
- `git` - push to their own GitHub
- `python3` - run whatever scripts
- `gcc/g++` - compile code
- `qwen-code` or `claude` - AI coding assistant
- Full internet access
- Persistent home directory

No forced commands. No lock-in. Just power.

---

## Johnny's Responsibilities

See `docs/JOHNNY-HANDOFF.md` for details:
- Landing page (make it dope)
- Auth flow (magic links / OAuth)
- Terminal UI (xterm.js wrapper)
- Docs page
- Mobile-first everything

---

## MVP Milestones

1. **Phase 1**: Single VM + C++ bridge working
2. **Phase 2**: Pool manager + Redis state
3. **Phase 3**: Persistent storage (Filestore)
4. **Phase 4**: Johnny's frontend integration
5. **Phase 5**: AI integration (qwen-code)
