# Cloud deploy (public demo)

One x86 VM running the normal compose stack, with Caddy in front for HTTPS and a shared demo login.
Public/anonymized data only (e.g. ds004100) — the app itself has no auth.

**Sizing**: FreeSurfer is x86-only and the server image is ~34GB on disk; recon-all wants ~8GB RAM per job.
Hetzner Cloud CX42-class (8 vCPU / 16GB / 160GB) is the sweet spot. CX32-class (4 vCPU / 8GB / 80GB) works with
`MAX_CONCURRENT_JOBS=1` but disk is tight.

## Steps

1. Create an Ubuntu 24.04 VM with your SSH key. Attach a firewall allowing only 22, 80, 443.
2. Point a DNS A record at it, or use `<ip-with-dashes>.sslip.io` as the hostname.
3. On the VM:
   ```bash
   curl -fsSL https://get.docker.com | sh
   git clone --recursive https://github.com/<you>/bellanes-lab.git && cd bellanes-lab/docker
   # copy your FreeSurfer license.txt to docker/license.txt (scp from your machine)
   cp .env.example .env   # set FS_LICENSE_HOST, WEB_PORT=127.0.0.1:8081, SITE_ADDRESS, DEMO_USER, DEMO_PASS_HASH
   ./build-base.sh
   docker compose -f docker-compose.yml -f docker-compose.cloud.yml up -d --build
   ```
4. Open `https://<SITE_ADDRESS>/` and log in with the demo credentials.

## Updating

```bash
git pull && docker compose -f docker-compose.yml -f docker-compose.cloud.yml up -d --build
```
Re-run `build-base.sh` only when `base.Dockerfile` changes.
