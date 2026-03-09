#!/bin/bash
# AI Coding Engineer - PicoClaw Execution

echo "🛠️ Starting AI Engineer via docker-compose (PicoClaw)..."

cd "/Users/amiyakumar.m/Ws/ai-space/picoclaw"

# 1. Clean up old containers to save RAM
docker compose down 2>/dev/null || sudo docker compose down 2>/dev/null

# 2. Build and Launch the main container
docker compose up -d --build || sudo docker compose up -d --build

if [ $? -eq 0 ]; then
    echo "✅ Success! Waiting for WhatsApp QR..."
    sleep 8
    docker compose logs -f picoclaw
else
    echo "❌ Execution failed."
    exit 1
fi
