# Frontend Handoff - Johnny's Domain

## Overview
You own everything the user sees before they enter the terminal. Make it beautiful, keep it light.

---

## Your Stack (Suggested)
- **Framework**: Svelte (compiles to vanilla JS, tiny bundle)
- **Terminal**: xterm.js (industry standard, VS Code uses it)
- **Styling**: Whatever makes it dope - just keep bundle < 100KB

---

## Pages to Build

### 1. Landing Page (`/`)
The hook. Show the vision.

Ideas:
- Live terminal demo (read-only, showing commands scrolling)
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

**Requirements:**
- Uses xterm.js
- Connects to WebSocket URL from auth flow
- Mobile keyboard friendly
- Quick-action buttons for common commands

### 4. Docs Page (`/docs`)
How to use the terminal. Could even be a read-only terminal itself.

---

## Integration Points

### Auth → Terminal Handoff

After successful auth, you'll get a WebSocket URL:

```javascript
// After magic link validation
const response = await fetch('/api/assign-instance', {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${token}` }
});

const { ws_url } = await response.json();
// ws_url = "wss://vm-03.4sb.io/shell?token=abc123"

// Connect xterm.js to this URL
const socket = new WebSocket(ws_url);
const term = new Terminal();
term.open(document.getElementById('terminal'));

socket.onmessage = (e) => term.write(e.data);
term.onData((data) => socket.send(data));
```

### Mobile Quick-Actions

These buttons just send text to the terminal:
```javascript
document.getElementById('ai-btn').onclick = () => {
  socket.send('qwen-chat\n');  // or 'claude\n'
};

document.getElementById('push-btn').onclick = () => {
  socket.send('git add . && git commit -m "update" && git push\n');
};
```

---

## Design Guidelines

### Vibe
- Terminal-core / Cyber-brutalist
- High contrast (works in sunlight)
- Dark mode default (saves battery on OLED)
- No tracking scripts, no analytics bloat

### Performance Targets
- First paint: < 1 second on 3G
- Total bundle: < 100KB
- Time to terminal: < 2 seconds after login

### Mobile Considerations
- Touch targets: minimum 44x44px
- Keyboard handling: don't fight the OS
- Orientation: works in portrait and landscape
- Quick-action bar: always visible above keyboard

---

## What You DON'T Need to Handle

The backend handles:
- VM provisioning
- Terminal sessions (PTY)
- User file storage
- AI integrations

You just need to:
1. Make it look dope
2. Handle auth
3. Connect xterm.js to the WebSocket we give you

---

## Assets We'll Provide

- API endpoint specs (OpenAPI)
- Test WebSocket URL for development
- User token format (JWT)

---

## Questions?

Ping the backend (us) for:
- WebSocket connection issues
- Auth flow changes
- New quick-action commands to add
