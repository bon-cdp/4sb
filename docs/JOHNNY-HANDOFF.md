# Frontend Handoff - Johnny's Domain

## Overview
You own everything the user sees before they enter the terminal. Make it beautiful, keep it light.

---

## Current Status (Dec 2025)

**We have a working terminal!**

Test it: `http://136.119.47.46:8080`

> **Note:** VM IPs can change. Run `gcloud compute instances list` to get current IPs.

This is a GCloud VM running `ttyd` - a battle-tested web terminal that handles WebSocket + xterm.js automatically. Each browser connection gets its own shell session.

### What's Live Now
- Auto-scaling VM group on GCloud (`fsb-terminal-group`)
- Pre-installed: git, python3, vim, nano, gcc, tmux
- Firewall open on port 8080
- GitHub repo: https://github.com/bon-cdp/4sb

### Current Limitation
Right now, everyone shares the same VM and filesystem. For production:
- Each user needs their own VM (we have auto-scaling ready)
- Each user needs their own home directory (Cloud Filestore coming)
- Auth needed to assign users to VMs

---

## Your Stack (Suggested)
- **Framework**: Svelte (compiles to vanilla JS, tiny bundle)
- **Styling**: Whatever makes it dope - just keep bundle < 100KB
- **Terminal**: ttyd handles this! Just iframe or redirect to the VM URL

---

## Pages to Build

### 1. Landing Page (`/`)
The hook. Show the vision.

Ideas:
- Live terminal demo (embed the test URL in an iframe?)
- "Get your terminal in 10 seconds" CTA
- No signup required to see what it's about
- Mobile-first, works on cracked Android screens

### 2. Auth Page (`/login`)
Keep it dead simple:
- Email input → Magic link sent
- Or: "Sign in with GitHub" (they'll use git anyway)
- No passwords to forget

### 3. Terminal Page (`/terminal`)
The main event:
```
┌──────────────────────────────────────┐
│  4sb terminal - user@4sb.io          │
├──────────────────────────────────────┤
│  $ _                                 │
│                                      │
│                                      │
│                                      │
│                                      │
├──────────────────────────────────────┤
│ [AI] [git push] [python] [help]      │  ← Mobile quick-actions
└──────────────────────────────────────┘
```

**Two Options:**

**Option A: Iframe/Redirect (Easiest)**
```html
<!-- Just embed ttyd directly -->
<iframe src="http://VM_IP:8080" style="width:100%;height:100%;border:none;"></iframe>
```

**Option B: Custom xterm.js (More Control)**
```javascript
// ttyd exposes WebSocket at /ws
const socket = new WebSocket('ws://VM_IP:8080/ws');
const term = new Terminal();
term.open(document.getElementById('terminal'));

socket.onmessage = (e) => term.write(e.data);
term.onData((data) => socket.send(data));
```

### 4. Docs Page (`/docs`)
How to use the terminal. Topics to cover:
- Git basics (clone, push, pull)
- Python quickstart
- How to use AI assistants (qwen-code, claude)
- SSH key setup for GitHub

---

## Integration Flow

### Simple Version (MVP)
```
User → Landing Page → Login → Redirect to http://VM_IP:8080
```

### Full Version (Later)
```
1. User logs in
2. Frontend calls POST /api/assign-instance
3. Backend assigns user to a warm VM from pool
4. Backend returns { vm_url: "http://34.x.x.x:8080" }
5. Frontend redirects/embeds that URL
```

### API We'll Build (Not Yet Live)
```
POST /api/assign-instance
Headers: Authorization: Bearer <jwt>
Response: { "vm_url": "http://<VM_IP>:8080", "expires": 3600 }
```

---

## Mobile Quick-Actions

If using custom xterm.js, add buttons that send commands:
```javascript
document.getElementById('ai-btn').onclick = () => {
  socket.send('qwen-chat\n');
};

document.getElementById('push-btn').onclick = () => {
  socket.send('git add . && git commit -m "update" && git push\n');
};

document.getElementById('python-btn').onclick = () => {
  socket.send('python3\n');
};
```

---

## Design Guidelines

### Vibe
- Terminal-core / Cyber-brutalist
- High contrast (works in sunlight on cheap phones)
- Dark mode default (saves battery on OLED)
- No tracking scripts, no analytics bloat

### Performance Targets
- First paint: < 1 second on 3G
- Total bundle: < 100KB gzipped
- Time to terminal: < 2 seconds after login

### Mobile Considerations
- Touch targets: minimum 44x44px
- Keyboard handling: don't fight the OS
- Orientation: works in portrait and landscape
- Quick-action bar: always visible above keyboard

---

## What You Handle vs What Backend Handles

### You (Frontend)
- Landing page design
- Auth flow (magic links, OAuth)
- User accounts database
- Terminal page UI/UX
- Docs

### Us (Backend)
- VM provisioning & scaling
- Terminal sessions (ttyd/PTY)
- User file storage (coming soon)
- AI integrations (qwen-code, claude)
- Assigning users to VMs

---

## Test Right Now

1. Open http://136.119.47.46:8080 on your phone
2. Try some commands:
   ```bash
   echo "hello 4sb"
   python3 -c "print('it works')"
   git --version
   ```
3. Think about how to make that experience beautiful

---

## Questions?

Ping the backend team for:
- New VM IPs if they change
- WebSocket connection issues
- Feature requests (what tools to pre-install)
- Auth integration when ready
