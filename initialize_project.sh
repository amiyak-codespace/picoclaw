#!/bin/bash

# --- CONFIGURATION ---
PROJECT_ROOT="/Users/amiyakumar.m/Ws/ai-space"
ENGINE_DIR="$PROJECT_ROOT/picoclaw"
WORKSPACE_DIR="$PROJECT_ROOT/ai-engineer"
GEMINI_KEY="AIzaSyCkEVSGkfAYnKXJzksHSn1RHafN1xZRRAo" # <--- PASTE KEY HERE

echo "🚀 Starting AI Engineer Environment Setup (PicoClaw)..."

# 1. Create Directory Structure
mkdir -p $ENGINE_DIR
mkdir -p $WORKSPACE_DIR/{backend,frontend,.agent/spec,.agent/prompts}
mkdir -p $PROJECT_ROOT/picoclaw_store

# 2. Create GEMINI.md (The Brain's Rules)
echo "🧠 Creating GEMINI.md persona..."
cat <<EOF > $WORKSPACE_DIR/GEMINI.md
# AI Coding Engineer Persona (Gemini 3 Powered)

## Role
You are a Senior Full-Stack Engineer. Your goal is to build, deploy, and maintain web applications on this Ubuntu EC2 instance.

## Technical Preferences
- **Backend:** Node.js (Express), MongoDB or SQLite.
- **Frontend:** React with Tailwind CSS (Vite preferred).
- **Deployment:** Run apps in the background using PM2 or Docker.
- **Ports:** Use 3000 for Frontend, 5000 for Backend.

## Behavior Rules
1. **Autonomy:** If a command requires a new directory or package, create/install it without asking.
2. **Persistence:** Check 'memory.sqlite' before starting a task to see how we did it last time.
3. **Deployment:** After writing code, always attempt to start the server and provide the local URL.
4. **Communication:** Keep WhatsApp replies concise. Send a summary of changes and the URL.
EOF

# 3. Create .env inside the engine folder
echo "🔑 Creating .env..."
cat <<EOF > $ENGINE_DIR/.env
GOOGLE_API_KEY=$GEMINI_KEY
WHATSAPP_ENABLED=true
TZ=Asia/Kolkata
AGENT_RULES_FILE=/app/workspace/GEMINI.md
EOF

# 4. Create docker-compose.yml
echo "🐳 Creating docker-compose.yml..."
cat <<EOF > $ENGINE_DIR/docker-compose.yml
services:
  picoclaw:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: picoclaw
    restart: unless-stopped
    env_file: .env
    volumes:
      - $WORKSPACE_DIR:/app/workspace
      - $PROJECT_ROOT/picoclaw_store:/app/store
      - /var/run/docker.sock:/var/run/docker.sock
    ports:
      - "18789:18789"
    deploy:
      resources:
        limits:
          memory: 2g
EOF

# 5. Set Permissions
chmod +x $ENGINE_DIR/run_engineer.sh 2>/dev/null || true
chmod +x $ENGINE_DIR/execute_engieer.sh 2>/dev/null || true
chmod +x $ENGINE_DIR/initialize_project.sh

echo "✅ Setup Complete!"
echo "Next step: Run 'cd $ENGINE_DIR && ./run_engineer.sh' to start your bot."
