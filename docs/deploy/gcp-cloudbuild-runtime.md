# OpenClaw on GCP with Cloud Build (oc-backy)

This setup builds the OpenClaw image on push and runs the VM in pull-only mode.

## 1) One-time setup

From repo root:

```bash
chmod +x scripts/gcp/setup-cloudbuild.sh scripts/gcp/switch-vm-to-registry-image.sh
./scripts/gcp/setup-cloudbuild.sh
```

Defaults:

- `PROJECT_ID=oc-backy`
- `REGION=us-central1`
- Artifact Registry repo: `openclaw`
- Trigger: `openclaw-main`
- GitHub repo: `mpsb00/openclaw`

## 2) Build once manually (sanity check)

```bash
gcloud config set project oc-backy
gcloud builds submit --config cloudbuild.yaml .
```

Expected image tags:

- `us-central1-docker.pkg.dev/oc-backy/openclaw/openclaw-gateway:main`
- `us-central1-docker.pkg.dev/oc-backy/openclaw/openclaw-gateway:<BUILD_ID>`

## 3) Switch VM runtime to registry image

```bash
./scripts/gcp/switch-vm-to-registry-image.sh
```

This script:

- Backs up `~/openclaw/.env` and `~/openclaw/docker-compose.yml` on VM
- Sets `OPENCLAW_IMAGE` to Artifact Registry image
- Removes local `build: .` from compose (runtime pull-only)
- Pulls image and restarts `openclaw-gateway`

## 4) Rollback (if needed)

SSH into the VM and restore latest backups:

```bash
cd ~/openclaw
ls -1t .env.backup.* | head -1
ls -1t docker-compose.yml.backup.* | head -1

cp "$(ls -1t .env.backup.* | head -1)" .env
cp "$(ls -1t docker-compose.yml.backup.* | head -1)" docker-compose.yml
docker compose up -d openclaw-gateway
```

## 5) Resize to e2-small after successful runtime tests

```bash
gcloud compute instances stop openclaw-gateway --zone=us-central1-a
gcloud compute instances set-machine-type openclaw-gateway --zone=us-central1-a --machine-type=e2-small
gcloud compute instances start openclaw-gateway --zone=us-central1-a
```

If runtime is unstable, revert:

```bash
gcloud compute instances stop openclaw-gateway --zone=us-central1-a
gcloud compute instances set-machine-type openclaw-gateway --zone=us-central1-a --machine-type=e2-medium
gcloud compute instances start openclaw-gateway --zone=us-central1-a
```
