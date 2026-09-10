# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

BellaNes Lab is a self-hosted research platform for SEEG analysis: electrode localization, brain surface reconstruction (FreeSurfer recon jobs), and seizure-focus computation (EI/HFO/SOZ, neural fragility). It began as a reproduction of the BrainQuake paper (PMC8782204) and became a research platform in its own right — the goals and validation strategy are in **[docs/roadmap.md](docs/roadmap.md)**; read it before making prioritization decisions. The paper's algorithms are one replaceable plugin, not the project's purpose.

## Workflow

Single developer. Work happens on `main` and commits go straight to `main` — no PR,
no review flow, no feature branches unless explicitly asked for one.

## Repository layout

```
server/             # FastAPI + SQLite REST service
web/                # React + Vite web UI (Mantine, react-three-fiber); the only client
docker/             # Dockerfiles + compose
fastsurfer-worker/  # optional GPU FastSurfer sidecar
freebrowse/         # submodule -> github.com/freesurfer/freebrowse
tools/              # benchmark/verification scripts (ds004100, R parity oracles)
docs/               # roadmap, benchmark reports, design notes
datasets/           # LOCAL ONLY, gitignored -- imaging + EEG
data/               # LOCAL ONLY, gitignored -- working data
```

**Data privacy**: `datasets/`, `data/`, and `server/data/` are gitignored and must stay that way — they hold imaging and EEG. Never commit files from these directories, never weaken those ignore rules, and never add sample/fixture data containing real recordings to the tree. This repository is public.

## Commands

### server

```bash
cd server

# First-time setup
python -m venv .venv
source .venv/bin/activate
pip install -e ".[test]"

# Run the API server
uvicorn app.main:app --reload --port 8000

# Run the background job worker (separate terminal)
python -m app.workers.jobs_worker

# Database migrations
alembic upgrade head
alembic revision --autogenerate -m "description"

# Run all tests
pytest

# Run a single test
pytest tests/test_api.py::test_full_e2e_flow
pytest tests/test_api.py::test_subject_crud
```

### server environment variables (via `.env` file or shell)

| Variable | Default | Notes |
|---|---|---|
| `SUBJECTS_DIR` | `./data/subjects` | FreeSurfer subject directory root |
| `FREESURFER_HOME` | `./data/freesurfer` | Path to FreeSurfer installation |
| `DATA_ROOT` | `./data` | Root for DB, logs, recv folder |
| `DB_URL` | `sqlite:///./data/bellanes.db` | SQLite in WAL mode |
| `FS_LICENSE` | `""` | Path to FreeSurfer license.txt — must be set to run recon jobs |
| `HOUGH3DLINES_BIN` | `hough3dlines` | Resolved on PATH |
| `MAX_CONCURRENT_JOBS` | `2` | Per-subject serialization is enforced separately in the worker |

## Architecture

**Server** (`server/app/`):
- `main.py` — FastAPI app with CORS; mounts routers for subjects, jobs, recon, electrodes
- `config.py` — single pydantic-settings source of truth for all env vars
- `db.py` — SQLAlchemy engine + `get_db` dependency; SQLite in WAL mode
- `models/` — SQLAlchemy ORM: `Subject`, `Job`, `Artifact`
- `schemas/` — Pydantic request/response models
- `routers/` — one file per resource group; each job-creating endpoint inserts a `queued` row and returns it
- `services/` — numeric modules: `recon.py`, `ct_register.py`, `electrodes.py`, `anatomy.py` (names the FreeSurfer structure each contact sits in), `ictal.py`, `interictal.py`, `soz.py`, `fragility.py`, `edf.py`/`edf_common.py`, `freebrowse.py`, `fastsurfer_client.py`, `job_control.py`
- `sigproc/` — the signal-processing core: `ei.py`, `hfo.py`, `fragility.py`, `fusion.py`, `filters.py`, `montage.py`, `scalp_montage.py`, `channels.py`, `clustering.py`
- `workers/jobs_worker.py` — polls `jobs` table for `queued` rows, claims one, runs it, writes a per-job log file to `DATA_ROOT/logs/job_{id}.log`. On startup, fails any stale `running` rows from a previous crash.

**Job state machine**: `queued → running → finished | failed | cancelled`

**Job types**: `recon`, `ct_register`, `elec_detect`, `elec_segment`, `ei_compute`, `hfo_compute`, `soz_fuse`, `fragility_compute`.

**File storage**: server disk under `SUBJECTS_DIR` (FreeSurfer convention) + `DATA_ROOT/recv/{subject}/` for raw uploads. DB records artifact kind + relative path; the files themselves are not in the DB.

**Tests** (`server/tests/`): use `fastapi.testclient.TestClient` + `unittest.mock.patch` on `subprocess.run` so tests run without FreeSurfer/FSL installed. The mock creates the expected output files so artifact-registration logic is fully exercised. Tests use a separate SQLite path (`./data/test_bellanes.db`) cleaned up in the `autouse` fixture.

## Recording formats

EDF in, EDF only. Converters from proprietary formats live in the separate **eeg2edf** repository. The server reads the `eeg2edf-sidecar/1` JSON those tools emit (`sigproc/scalp_montage.py`); that schema is specified in eeg2edf's `SIDECAR.md` and is an external contract — changing how it is parsed here means checking that spec.

## Upstream provenance

Ported from [HongLabTHU/BrainQuake](https://github.com/HongLabTHU/BrainQuake) (Apache-2.0), the reference implementation for PMC8782204. Paths below are in that upstream repository:

| Upstream source | What was ported | Home here |
|---|---|---|
| `Server_codes/utils.py` | `reconrun`/`fastrun`/`infantrun` shell-outs | `services/recon.py` |
| `Server_codes/eePipeline.py` | CT→MRI FSL registration pipeline | `services/ct_register.py` |
| `utils/elec_utils.py` | hough3dlines subprocess, GMM, `ElectrodeSeg` — split into `detect`/`segment` | `services/electrodes.py` |
| `client_ictal.py` | `compute_hfer`, `compute_ei_index`, `compute_full_band` | `services/ictal.py` |
| `utils/HI_apis.py` + `interictal_utils.py` | HFO/HI detection | `services/interictal.py` |
| `soz_result.py` | SOZ fusion/ranking (mayavi call dropped) | `services/soz.py` |

Do not rename references to the BrainQuake paper or the upstream repository — they are provenance, not this project's name.

## Status

- **Server + web app**: functional — subjects/jobs/recon/ct_register/electrodes/EI/HFO/SOZ/fragility routers + worker; tabbed web UI with Jobs drawer, FreeBrowse tab, 3D Slicer contact import.
- **Docker**: hierarchical two-image build, to keep the public image small and avoid rebuilding FreeSurfer/FSL on every app change. `docker/base.Dockerfile` (→ `bellanes-base`, built separately via `docker/build-base.sh`, not by compose) holds `FROM ubuntu:24.04` + FreeSurfer **8.2.0** (7.4.1's tarball didn't ship `infant_recon_all`; 8.x is only distributed as a `.deb` built against Ubuntu 24.04, installed via `apt-get install <local .deb>` so apt resolves its declared deps — the Dockerfile symlinks wherever the `.deb` installs `SetUpFreeSurfer.sh` to `/usr/local/freesurfer`, since hardcoded paths elsewhere expect that location) + FSL's `fsl-flirt` conda package only (`flirt` is the only FSL binary called; this replaced a full install costing ~10.5GB for one binary) + `hough-3d-lines` built from source in a discarded builder stage. `docker/Dockerfile` (→ `bellanes-server`) is `FROM bellanes-base` and adds only the Python venv + app code — edit this for a new apt/pip dependency, since it never touches the base layers. FS_LICENSE is mounted at runtime, never baked in. Validated on 7.4.1/22.04; the 8.2.0/24.04 base image has not yet been built/validated. A real end-to-end `recon-all` run is still open.

**Key constraint**: numeric-service correctness remains the highest-risk item. The strategy is (a) synthetic-signal characterization tests, and (b) cross-validation against independent implementations (ezfragility, AnyWave/epycom EI, independent HFO detectors) — see [docs/roadmap.md](docs/roadmap.md).

**Note**: You have a tendency to leave long multiline comments in generated code explaining all the decision logic that led to this function. I DON'T LIKE THIS. We're not writing a journal or a book.
Keep comments short and concise. Explain WHY only if it's not clear from the code, and only in 1-2 lines.

**Prefer the simple solution over the complete one.** When something can be fixed by deleting code or relaxing a constraint, do that instead of adding a parallel code path, a second data structure, or new metadata. If a proposal introduces a detection heuristic or a DB field, look for the degrade-gracefully version first.

**Workflow rule**: Every 5 consecutive tasks / shell runs you do on your own, you pause, and let the user know what you are trying to achieve, current progress, next steps.
