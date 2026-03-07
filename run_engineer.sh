#!/bin/bash
CONTAINER_NAME="picoclaw"
IMAGE_NAME="picoclaw-agent"

echo "Cleaning up old containers..."
docker stop $CONTAINER_NAME 2>/dev/null
docker rm $CONTAINER_NAME 2>/dev/null

echo "Building and Launching PicoClaw..."
cd /Users/amiyakumar.m/Ws/ai-space/picoclaw
docker build -t $IMAGE_NAME .
docker run -d \
  --name $CONTAINER_NAME \
  -e WHATSAPP_ENABLED=true \
  -e GOOGLE_API_KEY="AIzaSyCkEVSGkfAYnKXJzksHSn1RHafN1xZRRAo" \
  -v "/Users/amiyakumar.m/Ws/ai-space/ai-engineer:/app/workspace" \
  -v "/Users/amiyakumar.m/Ws/ai-space/picoclaw_store:/app/store" \
  -p 18789:18789 \
  --restart unless-stopped \
  $IMAGE_NAME

echo "-------------------------------------------------------"
echo "WAITING FOR WHATSAPP QR CODE..."
echo "-------------------------------------------------------"
sleep 10
docker logs $CONTAINER_NAME | grep -A 20 "QR" || docker logs $CONTAINER_NAME
