# BellaNes Lab

A self-hosted research platform for pre-surgical SEEG epilepsy analysis:
electrode localization, FreeSurfer brain-surface reconstruction, and
seizure-focus computation (EI, HFO, SOZ fusion, neural fragility), through a
browser UI backed by a job-queue server.

## Contents

- [Overview](#overview)
- [Roadmap](#roadmap)
- [Repository layout](#repository-layout)
- [Running it](#running-it)
- [Provenance](#provenance)
- [License](#license)

## Overview

BellaNes Lab began as a reproduction of the [BrainQuake paper and its published
code](https://pmc.ncbi.nlm.nih.gov/articles/PMC8782204/) and grew into a
different thing: a self-hosted platform that runs the full SEEG pre-surgical
pipeline as background jobs — FreeSurfer reconstruction, CT↔MRI registration,
electrode contact detection/segmentation (including import from 3D Slicer),
and epileptogenicity computation (EI/HFO/SOZ/fragility) — with a React web UI
to drive it and inspect results (including a FreeBrowse tab for browsing
FreeSurfer volumes and surfaces without a local install).

The architecture is FastAPI + SQLite (`server/`) with a React + Vite + Mantine
web client (`web/`), both packaged as Docker images.

## Roadmap

**[docs/roadmap.md](docs/roadmap.md)** states what this project is for and
where it's headed — read it before making prioritization calls. In short: the
paper's own algorithms are one replaceable component in a larger platform, not
the point of the project.

## Repository layout

```
server/             # FastAPI + SQLite REST service, job worker
web/                # React + Vite web UI (Mantine, react-three-fiber) -- the client
docker/             # Dockerfiles + compose (base image w/ FreeSurfer+FSL, app, web)
fastsurfer-worker/  # optional GPU FastSurfer sidecar service
freebrowse/         # submodule: FreeSurfer's FreeBrowse viewer, served by the web image
tools/              # benchmark + verification scripts (OpenNeuro ds004100, R parity oracles)
docs/               # roadmap, benchmark reports, design notes
datasets/           # LOCAL ONLY, gitignored -- imaging + EEG
data/               # LOCAL ONLY, gitignored -- working data, SQLite DB, job logs
```

Clone with submodules, or the web image will not build:

```bash
git clone --recurse-submodules <url>
# or, in an existing clone:
git submodule update --init
```

## Running it

### Docker (recommended)

```bash
# 1. Get a free FreeSurfer license: https://surfer.nmr.mgh.harvard.edu/registration.html
# 2. cp docker/.env.example docker/.env and point FS_LICENSE_HOST at it
# 3. Build the base image once (FreeSurfer + FSL + hough-3d-lines -- rarely changes):
docker/build-base.sh
# 4. Build and start the app:
docker compose -f docker/docker-compose.yml up --build
# 5. Open http://<host>:${WEB_PORT:-80}/
```

### Local development

Server:
```bash
cd server
python -m venv .venv && source .venv/bin/activate
pip install -e ".[test]"
uvicorn app.main:app --reload --port 8000       # API
python -m app.workers.jobs_worker               # job worker, separate terminal
pytest                                           # tests
```

Web:
```bash
cd web
npm install
npm run dev
```

See [CLAUDE.md](CLAUDE.md) for environment variables, architecture notes, and
job types.

## Recording formats

This repository consumes EDF. Converters from proprietary clinical formats
(Nihon Kohden, Nicolet/Nervus, Micromed VWR) live in a separate repository,
**eeg2edf**. The server reads the `eeg2edf-sidecar/1` JSON those converters
emit — `server/app/sigproc/scalp_montage.py` parses it for per-channel
reference information. That schema is specified in eeg2edf's `SIDECAR.md`.

## Provenance

This project started from [BrainQuake](https://github.com/HongLabTHU/BrainQuake)
(Apache-2.0), the reference implementation accompanying
[the paper](https://pmc.ncbi.nlm.nih.gov/articles/PMC8782204/). The numeric
services under `server/app/services/` are ports of that code; each module's
header comment records its source file, and `CLAUDE.md` carries the full
porting table. See [NOTICE](NOTICE) for attribution.

## License

Apache 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
