# Cleanup plan: review order and conventions

**Date:** 2026-08-09. Companion to [roadmap.md](roadmap.md).

> A first part, describing removal of the PyQt5 v1 client/server, was dropped: that
> work was executed in the predecessor repository, which this one never contained.
> What remains is the review order, marking conventions and synthetic-test plan,
> which are still current.

## Cleanup, readability, review

### Scope

- `server/`: ~56 Python files — app (config, db, models, schemas, 13
  routers, ~14 services, workers) + 4 test files.
- `web/`: 75 files — API layer (client, endpoints, types, ~13 query hooks),
  EEG viewer components, three.js scene components, feature tabs.

### Review order (by risk, highest first)

The numeric services decide scientific correctness and were ported from rough
v1 code with **zero tests on the math**. They come first:

1. `services/ictal.py` + `services/signal_filters.py` — EI/HFER; already has a
   known unreconciled discrepancy (see
   the EI-vs-annotation notes kept with the case material).
   Specific attention: `determine_threshold_onset` baseline sensitivity,
   `1/onset_rank` weighting, crop/window handling, saturation blindness.
2. `services/electrodes.py` — hough3dlines + GMM contact segmentation; feeds
   every spatial result. Coordinate-space conventions (voxel vs RAS) audited
   end-to-end, including the 3D Slicer import path
   (`routers/electrodes.py`, `patient_io.py`, web `SlicerContactsPreview`).
3. `services/interictal.py` — HFO/HI detection.
4. `services/soz.py` — fusion/ranking.
5. `services/{edf,edf_common}.py` — channel naming, units, annotation parsing
   (the layer most likely to silently corrupt everything downstream).
6. `workers/jobs_worker.py` + `services/job_control.py` — crash/stale-job
   handling, concurrency.
7. Routers + schemas — thin, review for consistency and error handling.
8. `web` — EEG viewer state (`useEegViewerState`), three.js contact
   rendering (coordinate handling again), API layer last.

### Marking convention for bad code

Findings land in two places so they're both greppable and triaged:

- **In code**: `# FIXME(correctness): ...` for suspected wrong behavior,
  `# TODO(cleanup): ...` for readability/structure debt,
  `# NOTE(v1-quirk): ...` where v1 behavior was preserved deliberately and
  looks wrong but changing it needs a decision. Same tags in TS (`//`).
- **In `docs/code-review-findings.md`** (created during the review): one line
  per finding — file:line, severity (high = could corrupt results silently,
  medium = fragile/unclear, low = style), status. High-severity correctness
  items get fixed in the same pass; the rest get marked and batched.

### Readability pass (per module, same visit as review)

- Rename v1-inherited names that obscure meaning (`trackRecognition`,
  `CTresult_dir`, single-letter loop state) — keep a provenance comment where
  the v1 name aids cross-referencing against
  [HongLabTHU/BrainQuake](https://github.com/HongLabTHU/BrainQuake).
- Docstrings on every service entry point stating **units, array shapes,
  coordinate space, channel-name conventions** — the three bug classes this
  project has actually hit.
- Delete dead code and commented-out v1 remnants (git history keeps them).
- Type hints on service signatures (not a full mypy campaign — signatures and
  return types where they document intent).

### Tests to add while reviewing (cheap, no golden outputs needed)

Synthetic-signal characterization tests for the pure numeric functions:

- EI on a synthetic recording with a known injected onset channel → that
  channel must rank first; shifting the injection shifts the ranking.
- Filters: pass/stop-band behavior on synthetic tones (incl. 50 vs 60 Hz mains).
- HFO detector on synthetic ripples at known times → detected count/timing.
- Contact segmentation on a synthetic point cloud of K straight shafts → K
  shafts recovered with correct contact counts.
- EDF layer: channel-name round-trip with primed names (`X'12`), annotation
  time math (the clip-elapsed-offset trap from the discrepancy doc).

These double as the layer-2 (implementation) isolation instrument from
[roadmap.md](roadmap.md): a port that fails synthetic
sanity checks is buggy regardless of any clinical ground truth.

### Tooling baseline (once, before the module passes)

- `ruff check` + `ruff format` for `server` (config in `pyproject.toml`),
  autofix the noise first so review diffs stay readable.
- `eslint` + `tsc --noEmit` clean for `web`.
- Optional: pre-commit hooks once both are green.

### Sequencing

1. Part 1 (legacy removal) — one commit, verified.
2. Tooling baseline — one commit of autofixes, zero manual changes mixed in.
3. Module-by-module review in the risk order above — one commit per module,
   findings logged, high-severity fixes included, synthetic tests added with
   the module they cover.
