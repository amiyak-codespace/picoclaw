# Long-term Memory

This file stores important information that should persist across sessions.
**Always read this at the start of every conversation.**

## Setup & Infrastructure

- **Engine:** PicoClaw running in Docker container on Mac local + EC2
- **Config:** `/root/.picoclaw/config.json` — Gemini Flash model, WhatsApp native channel
- **Data persistence:** `./data/picoclaw/` volume mount (WhatsApp session, workspace, memory)
- **Docker socket:** Mounted at `/var/run/docker.sock` — can run docker commands
- **Dev workspace:** `/root/ws/ai-space/ai-engineer/` — all projects go here
- **Migration:** Moved from NanoClaw (Node.js/TypeScript) to PicoClaw (Go) for efficiency

## Active Projects

*(Update this section as projects are built)*

- None yet — awaiting first WhatsApp command

## Key Facts

- User communicates via WhatsApp — always keep replies short and action-focused
- After every task: send ✅ what was done + 🌐 URL + 📁 files created
- Always deploy after coding — don't just write code without starting the service
- User is the developer — respect their autonomy, don't over-explain

## Preferences Learned

- Stack: React/Vite/Tailwind (frontend), Express/FastAPI (backend), SQLite/MongoDB
- Ports: 3000=frontend, 5000=backend
- Deployment: Docker Compose preferred
- Timezone: Asia/Kolkata

## Important Commands

```bash
# Check running containers
docker ps

# View picoclaw logs
docker logs picoclaw

# Restart picoclaw
cd /Ws/ai-space/picoclaw && docker compose restart

# Build and deploy a new project
cd /root/ws/ai-space/ai-engineer && mkdir <project> && ...
```