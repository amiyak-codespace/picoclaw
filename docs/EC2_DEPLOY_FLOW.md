# PicoClaw EC2 Deployment Flow (AppsMagic)

This document captures the exact production flow used for `picoclaw` on EC2.

## 1) Repo and Branch Model

- `upstream`: `https://github.com/sipeed/picoclaw.git`
- `origin` (private mirror): `https://github.com/amiyak-codespace/picoclaw-private.git`
- `fork` (public fork): `https://github.com/amiyak-codespace/picoclaw.git`

Rule:
- Always raise feature/fix PRs to `origin` (`picoclaw-private`).
- Keep `origin/main` synced with `upstream/main` before production deploy.

## 2) Sync-First Rule (Before Every Deploy)

Trigger upstream sync workflow:

```bash
gh workflow run "Upstream Sync PR" --repo amiyak-codespace/picoclaw-private
```

Wait for run:

```bash
gh run list --repo amiyak-codespace/picoclaw-private --workflow "Upstream Sync PR" --limit 1
gh run watch <run_id> --repo amiyak-codespace/picoclaw-private --exit-status
```

If sync PR is created (head `upstream-sync`), merge it:

```bash
gh pr list --repo amiyak-codespace/picoclaw-private --state open --head upstream-sync
gh pr merge <pr_number> --repo amiyak-codespace/picoclaw-private --merge --delete-branch
```

## 3) Code Maintain Flow

1. Create branch from latest `origin/main`.
2. Make changes, commit, push branch.
3. Raise PR to `origin/main`.
4. Resolve conflicts by merging `origin/main` into feature branch.
5. Merge PR.
6. Deploy only from merged `origin/main`.

## 4) EC2 Runtime Paths and Mounts

EC2 host:
- Repo: `/home/ubuntu/Ws/ai-space/picoclaw`
- Persistent store: `/home/ubuntu/Ws/ai-space/picoclaw_store`
- Workspace mount: `/home/ubuntu/Ws/ai-space/ai-engineer`

Container mounts (must remain exactly):
- `/home/ubuntu/Ws/ai-space/picoclaw_store -> /root/.picoclaw`
- `/home/ubuntu/Ws/ai-space/ai-engineer -> /root/ws/ai-space/ai-engineer`
- `/var/run/docker.sock -> /var/run/docker.sock`

## 5) Standard EC2 Deploy (Build on EC2)

```bash
ssh -i /Users/amiyakumar.m/Ws/ssh/apps-magic-ec2.pem ubuntu@44.204.150.112
cd /home/ubuntu/Ws/ai-space/picoclaw

git fetch origin --prune
git checkout main
git reset --hard origin/main

AI_SPACE_DIR=/home/ubuntu/Ws/ai-space docker compose up -d --build picoclaw
```

## 6) Fast Deploy Fallback (Build Local, Copy Image)

Use when EC2 build fails or is too slow.

### 6.1 Build locally for EC2 architecture

Important: EC2 is `linux/amd64`, so build amd64 image.

```bash
cd /Users/amiyakumar.m/Ws/ai-space/picoclaw
git fetch origin --prune
git checkout main
git reset --hard origin/main

docker buildx build --platform linux/amd64 -t picoclaw-picoclaw:latest --load .
```

### 6.2 Transfer image to EC2

```bash
docker save picoclaw-picoclaw:latest | \
ssh -i /Users/amiyakumar.m/Ws/ssh/apps-magic-ec2.pem ubuntu@44.204.150.112 'docker load'
```

### 6.3 Start on EC2 without rebuild

```bash
ssh -i /Users/amiyakumar.m/Ws/ssh/apps-magic-ec2.pem ubuntu@44.204.150.112 '
  cd /home/ubuntu/Ws/ai-space/picoclaw && \
  AI_SPACE_DIR=/home/ubuntu/Ws/ai-space docker compose up -d --no-build --force-recreate picoclaw
'
```

## 7) Post-Deploy Verification Checklist

```bash
# container status
ssh -i /Users/amiyakumar.m/Ws/ssh/apps-magic-ec2.pem ubuntu@44.204.150.112 \
  'docker ps --format "table {{.Names}}\\t{{.Status}}\\t{{.Image}}" | grep picoclaw'

# health and ready
ssh -i /Users/amiyakumar.m/Ws/ssh/apps-magic-ec2.pem ubuntu@44.204.150.112 \
  'echo HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18790/health) READY=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18790/ready)'

# mount verification
ssh -i /Users/amiyakumar.m/Ws/ssh/apps-magic-ec2.pem ubuntu@44.204.150.112 \
  'docker inspect picoclaw --format "{{range .Mounts}}{{println .Source \"->\" .Destination}}{{end}}"'

# image architecture verification
ssh -i /Users/amiyakumar.m/Ws/ssh/apps-magic-ec2.pem ubuntu@44.204.150.112 '
  IMAGE_ID=$(docker inspect -f "{{.Image}}" picoclaw) && \
  docker image inspect $IMAGE_ID --format "IMAGE_ARCH={{.Architecture}}"
'
```

Expected:
- `HEALTH=200`
- mounts include `picoclaw_store -> /root/.picoclaw`
- `IMAGE_ARCH=amd64`

## 8) WhatsApp Login Notes

- Session persists in: `/home/ubuntu/Ws/ai-space/picoclaw_store/workspace/whatsapp`
- If logged out, restart and scan QR from logs:

```bash
ssh -i /Users/amiyakumar.m/Ws/ssh/apps-magic-ec2.pem ubuntu@44.204.150.112 \
  'cd /home/ubuntu/Ws/ai-space/picoclaw && AI_SPACE_DIR=/home/ubuntu/Ws/ai-space docker compose restart picoclaw && docker logs -f picoclaw'
```

## 9) Common Failure Modes

1. `no space left on device` during build
- Run `docker builder prune -af` and `docker image prune -af`.
- If still failing, use local-build/copy-image fallback.

2. `exec format error`
- Wrong image architecture (arm64 image on amd64 EC2).
- Rebuild with `--platform linux/amd64` and redeploy.

3. `READY=503` while `HEALTH=200`
- Service started but channel readiness not complete yet.
- Check `docker logs picoclaw` for channel/auth status.
