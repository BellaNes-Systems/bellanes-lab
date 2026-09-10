# Roadmap: what this project is and where it's going

This document states what BellaNes Lab is for and how its correctness is
established. Read it before making prioritization calls.

## What this project is

It started as an effort to reproduce the BrainQuake paper
([PMC8782204](https://pmc.ncbi.nlm.nih.gov/articles/PMC8782204/)) with its
published code and dataset. The code needed enough bug-fixing and rebuilding
along the way that the project became something else: a **self-hosted research
platform for SEEG analysis** — a FastAPI server that runs FreeSurfer recon and
registration jobs, a React web UI, 3D Slicer contact import (replacing the
paper's unreliable detection), and a FreeBrowse tab for inspecting FreeSurfer
output without a local install.

The paper's algorithms (EI, HFO, SOZ fusion) are **one replaceable plugin**
inside that platform, not its purpose.

## The central problem: no method is trustworthy alone

Every localization method here — EI, HFO rate, neural fragility, cEI — is a
published statistic with published failure modes. Any single one of them can
rank the wrong shaft first on a real case, and none carries a calibrated
confidence. The design consequence is that the platform must run **several
independent methods and show where they agree and disagree**, rather than
presenting one number as an answer.

That is why the SOZ result is a fusion with an explicit run picker, and why
disagreement between methods is treated as a finding to investigate rather
than a bug to average away.

## How correctness is established

Numeric-service correctness is the highest-risk item in the project. There is
no golden-output harness against the original implementation — the legacy app
depended on manual GUI inputs it never persisted, so its outputs cannot be
reproduced. The strategy is therefore two-track:

**1. Synthetic-signal characterization.** Construct signals whose correct
answer is known by construction — a known spectral ratio, a known number of
ripples, a known unstable mode — and assert the pipeline recovers it. This
catches sign errors, off-by-one windows, filter misapplication and unit
mistakes, which is most of what actually goes wrong.

**2. Cross-validation against independent implementations.** Where another
group has implemented the same statistic, run both on the same input and
compare rankings:

| Method | Independent reference | State |
|---|---|---|
| Neural fragility | `ezfragility` (R) | R is the parity oracle; Python port checked against it |
| EI | EZEI (R), AnyWave/epycom | benchmarked on ds004100 — see `ezei_comparison_ds004100.md` |
| HFO | independent detectors | not yet done |
| cEI | none available | feasibility spike, see `cei_evaluation.md` |

Public benchmark data is OpenNeuro **ds004100** (SEEG + ECoG with resection
and outcome labels). `tools/run_ds004100_comprehensive_benchmark.py` runs every
arm over the cohort and emits the comparison report.

## Validation roadmap

1. **Referencing is a first-class variable.** CAR and bipolar give materially
   different contact-level rankings for the same recording. Both are computed;
   neither is assumed. See `ei_reference_montage_ds004100.md`.
2. **Fit stability before interpretation.** An LTV estimator that has not
   converged produces a fragility map that looks plausible and means nothing.
   Stability is enforced and reported, not assumed.
3. **Saturation and data-quality screening.** Railed channels have meaningless
   windowed energy. Screening runs before any statistic.
4. **Algorithms, plural.** Add methods with independent failure modes rather
   than tuning one method harder — the value is in the disagreement structure.
5. **Anatomy grounding.** Every contact carries the FreeSurfer structure it
   sits in, so rankings can be read anatomically rather than as channel names.

## Evidence state

- **EI**: implemented, benchmarked on ds004100 against EZEI. Bipolar
  outperforms CAR on SOZ recall in that cohort.
- **Fragility**: Python port matches the R reference; LTV fit stability is
  enforced. Aggregation from contacts to shafts is size-normalized.
- **HFO**: implemented, not independently cross-validated. Lowest-confidence
  component.
- **SOZ fusion**: combines available arms with an explicit run picker; degrades
  to EI-only when HFO is absent.
- **Recon / registration / electrode localization**: functional; contact import
  from 3D Slicer is the reliable path, detection from CT is the fallback.

## Non-goals

- Clinical decision support. This is a research platform; nothing here is
  validated for care and it must not be presented as if it were.
- Reproducing the paper faithfully. That was the starting point, not the goal;
  where the paper's method is wrong or underspecified, it gets replaced.
