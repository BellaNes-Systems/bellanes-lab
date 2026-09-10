# CAR vs bipolar reference for EI, on ds004100

**Date:** 2026-08-16
**Question:** our EI applies a common-average reference; Bartolomei 2008 and Brainstorm's
epileptogenicity process both use bipolar. Does the choice change SOZ localization?

**Answer: yes, on SEEG.** Bipolar improves mean SOZ recall by **+7.4 pp** per subject
(27.2% → 34.6%, Wilcoxon p = 0.0066, better on 24/37 subjects). On ECoG grids it makes no
reliable difference, which is expected — see the caveat below.

## Setup

- 213 ictal runs, 57 subjects, OpenNeuro `ds004100` (`/media/data/eeg/ds004100`).
- Identical windows both arms: baseline `t_onset-60 → t_onset-10`, target `t_onset → t_onset+15`.
- `ei_method=band_ratio`, Bartolomei bands (3.5–12.4 / 12.4–97 Hz), prefilter 1–500 Hz.
- Only the reference differs.
- Both arms evaluated all 213 runs, so the comparison is fully paired — no run counted
  for one arm and not the other.
- Bipolar scores name pairs; ground truth names contacts. Each pair's score is projected
  onto both member contacts by max (`montage.project_pairs_to_contacts`).
- Top-K is K = number of ground-truth SOZ contacts for that run.

Reproduce:

```bash
cd server
.venv/bin/python ../tools/verify_ds004100_full.py --mode ei --reference car \
  --output-csv ../verification_results/ds004100_ei_car.csv \
  --output-html ../verification_results/ds004100_ei_car.html
.venv/bin/python ../tools/verify_ds004100_full.py --mode ei --reference bipolar \
  --output-csv ../verification_results/ds004100_ei_bipolar.csv \
  --output-html ../verification_results/ds004100_ei_bipolar.html
.venv/bin/python ../tools/compare_ei_reference.py \
  ../verification_results/ds004100_ei_car.csv ../verification_results/ds004100_ei_bipolar.csv \
  --label-a CAR --label-b BIPOLAR
```

Full output: `verification_results/ds004100_reference_comparison.txt` (gitignored).

## Results

Per-subject means (the headline: runs within a patient share an implantation and a focus,
so 213 runs are not 213 independent samples). p from Wilcoxon signed-rank on subject means.

### SEEG — 143 runs, 37 subjects

| metric | CAR | bipolar | delta | p |
|---|---:|---:|---:|---:|
| mean SOZ recall | 27.23% | **34.59%** | +7.36 pp | 0.0066 |
| mean resection concordance | 26.50% | **31.32%** | +4.82 pp | 0.0290 |

Run-level: SOZ top-K hit rate 67.13% → **74.13%** (+7.0 pp); bipolar better on 61 runs,
worse on 29.

### ECoG — 70 runs, 20 subjects

| metric | CAR | bipolar | delta | p |
|---|---:|---:|---:|---:|
| mean SOZ recall | 25.41% | 26.27% | +0.86 pp | 0.95 |
| mean resection concordance | 30.08% | 33.99% | +3.91 pp | 0.31 |

Run-level SOZ top-K hit rate *drops*, 77.14% → 68.57%.

**Why ECoG is excluded from the conclusion**: `montage.bipolar_pairs` pairs adjacent
contact numbers along a shaft, which is the right model for a depth electrode and the
wrong one for a grid — on an 8×8 grid, contacts 8 and 9 are on opposite edges of adjacent
rows, so a fraction of the pairs difference two non-neighbouring sites. The null result
here is evidence about that model, not about bipolar referencing on ECoG. Doing this
properly needs grid geometry, which ds004100's channel tables don't carry.

## Notes

- The CAR arm reproduces the previously reported 26.5% mean SOZ recall from
  `ezei_comparison_ds004100.md` exactly, so the refactor that added `--reference` did not
  disturb existing behaviour.
- **This puts a caveat on `ezei_comparison_ds004100.md`.** That benchmark scored our CAR
  pipeline against EZEI and reported a +9.6 pp SOZ hit-rate win. Bipolar alone moves our
  SEEG numbers by a comparable amount, so if EZEI references differently, part of that
  reported gap is a montage difference rather than a method difference. What EZEI does
  internally has not been checked.
- ds004100 label conventions are heterogeneous (`LAF1`, `EEG RG 01-Ref`, `AMFG-A2`,
  `RAF1-3`). `montage.parse_contact` handles all of them by treating trailing digits as
  the contact number and everything before as the shaft. A first version that only
  handled `LAF1` silently failed on ~40% of runs — which would have compared bipolar on a
  subset against CAR on everything.
- ~71 channel labels in the dataset (`RAF1-3` style) may already be bipolar derivations,
  in which case differencing them again is a double difference. Small enough to ignore
  here; no attempt was made to detect it.

## Shipped in the app (2026-08-16)

`reference` is now selectable per EI job, defaulting to **bipolar** for new jobs. A job
whose `params_json` predates the field replays as CAR, so retrying an old job reproduces
its original result rather than silently switching method.

The npz stores both levels: `chn_names`/`ei` hold the analysed channels (derivations under
bipolar — that is what was measured), and `contact_names`/`ei_by_contact` hold the
projection onto contacts. `services/soz.py::load_ei_result` prefers the projection, which
is what keeps `fuse_ei_hfo_scores` and the 3D view joining on contact names unchanged.
Without it a bipolar run would have produced `A1-A2` names, matched nothing, and silently
degraded to an HFO-only fusion — pinned by
`tests/test_soz_matching.py::test_bipolar_ei_archive_loads_keyed_by_contact`.

The EDF window endpoint takes `reference` too, so the result panel's per-channel
drill-down can show the actual bipolar derivation — which is also the spectrogram you need
for Brainstorm-style band selection.

## Still open

- **Native pair support downstream.** `fusion.py`, `soz.py` and the 3D viewer see only the
  contact projection; they cannot show that `A8-A9` was the hot derivation. Fine for
  ranking, a real limitation for interpretation.
- **ECoG grids.** Adjacent-number pairing is wrong for a 2-D grid; doing it properly needs
  grid geometry the channel tables don't carry.
- **EZEI's referencing** is still unchecked, so the caveat on
  `ezei_comparison_ds004100.md` stands.
- **The EI/fragility disagreement on our index case** (the most fragile shaft sits mid-pack under both references) is
  untouched by any of this, and is the more interesting question.
