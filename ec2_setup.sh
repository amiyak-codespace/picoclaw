#!/bin/bash
set -e

echo "🚀 Starting Full PicoClaw EC2 Setup..."

# 1. Update system and install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker $USER
    echo "⚠️ Docker installed. You might need to log out and log back in for group changes to take effect."
fi

# Set common variables for EC2 environment
EC2_WORKSPACE="$HOME/ws/ai-space"
mkdir -p "$EC2_WORKSPACE/picoclaw"
mkdir -p "$EC2_WORKSPACE/picoclaw_store"
mkdir -p "$EC2_WORKSPACE/ai-engineer"

# 2. Clone PicoClaw if not already present
if [ ! -d "$EC2_WORKSPACE/picoclaw/.git" ]; then
    echo "📦 Cloning PicoClaw engine..."
    git clone https://github.com/amiyak-codespace/picoclaw.git "$EC2_WORKSPACE/picoclaw"
else
    echo "✅ PicoClaw already exists, skipping clone."
fi

echo "📂 Creating EC2-optimized initialize_project.sh..."
cat << 'EOF' > "$EC2_WORKSPACE/picoclaw/initialize_project.sh"
#!/bin/bash

# --- CONFIGURATION ---
PROJECT_ROOT="$HOME/ws/ai-space"
ENGINE_DIR="$PROJECT_ROOT/picoclaw"
WORKSPACE_DIR="$PROJECT_ROOT/ai-engineer"
GEMINI_KEY="AIzaSyCkEVSGkfAYnKXJzksHSn1RHafN1xZRRAo"

echo "🚀 Starting AI Engineer Environment Setup (PicoClaw EC2)..."

# 1. Create Directory Structure
mkdir -p $ENGINE_DIR
mkdir -p $WORKSPACE_DIR/{backend,frontend,.agent/spec,.agent/prompts}
mkdir -p $PROJECT_ROOT/picoclaw_store

# 2. Create GEMINI.md (The Brain's Rules)
echo "🧠 Creating GEMINI.md persona..."
cat << 'INNER_EOF' > "$WORKSPACE_DIR/GEMINI.md"
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
INNER_EOF

# 3. Create .env
cat << 'INNER_EOF' > "$ENGINE_DIR/.env"
GOOGLE_API_KEY=AIzaSyCkEVSGkfAYnKXJzksHSn1RHafN1xZRRAo
WHATSAPP_ENABLED=true
TZ=Asia/Kolkata
AGENT_RULES_FILE=/app/workspace/GEMINI.md
INNER_EOF

# 4. Override docker-compose.yml
cat << 'INNER_EOF' > "$ENGINE_DIR/docker-compose.yml"
services:
  picoclaw:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: picoclaw
    restart: unless-stopped
    env_file: .env
    volumes:
      - $HOME/ws/ai-space/ai-engineer:/app/workspace
      - $HOME/ws/ai-space/picoclaw_store:/app/store
      - /var/run/docker.sock:/var/run/docker.sock
    ports:
      - "18789:18789"
    deploy:
      resources:
        limits:
          memory: 2g
INNER_EOF

# 5. Set Permissions
chmod +x "$ENGINE_DIR/run_engineer.sh" 2>/dev/null || true
chmod +x "$ENGINE_DIR/execute_engieer.sh" 2>/dev/null || true

echo "✅ Setup Complete!"
EOF

echo "📂 Creating EC2-optimized execute_engieer.sh..."
cat << 'EOF' > "$EC2_WORKSPACE/picoclaw/execute_engieer.sh"
#!/bin/bash
# AI Coding Engineer - EC2 Execution (PicoClaw)

echo "🛠️ Starting AI Engineer via docker-compose..."

cd "$HOME/ws/ai-space/picoclaw"

# 1. Clean up old containers to save RAM
docker compose down 2>/dev/null || sudo docker compose down 2>/dev/null

# 2. Build and Launch the main container
docker compose up -d --build || sudo docker compose up -d --build

if [ $? -eq 0 ]; then
    echo "✅ Success!"
else
    echo "❌ Execution failed."
    exit 1
fi
EOF

chmod +x "$EC2_WORKSPACE/picoclaw/initialize_project.sh"
chmod +x "$EC2_WORKSPACE/picoclaw/execute_engieer.sh"

echo "▶️ Executing initialize_project.sh..."
bash "$EC2_WORKSPACE/picoclaw/initialize_project.sh"

echo "▶️ Executing execute_engieer.sh..."
bash "$EC2_WORKSPACE/picoclaw/execute_engieer.sh"

# Wait for init
echo "⏳ Waiting 10s for container to initialize..."
sleep 10

# Start WhatsApp Auth
echo "📱 Triggering WhatsApp Authentication..."
echo "---------------------------------------------------------"
echo "To link your WhatsApp, we will generate a pairing code for +918599856571."
cd "$EC2_WORKSPACE/picoclaw"
sudo docker exec picoclaw npx tsx src/whatsapp-auth.ts --pairing-code --phone 918599856571 || docker exec picoclaw npx tsx src/whatsapp-auth.ts --pairing-code --phone 918599856571

echo "---------------------------------------------------------"
echo "✅ EC2 Deployment Complete!"
