#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${REPO_ROOT}/verification_results"
mkdir -p "$OUTPUT_DIR"

WORKERS="${1:-12}"

echo "======================================================================"
echo "   Running BellaNes Lab Comprehensive Benchmark on ds004100"
echo "   Parallel Workers: $WORKERS"
echo "======================================================================"

"${PYTHON:-python3}" "$SCRIPT_DIR/run_ds004100_comprehensive_benchmark.py" \
    --dataset "${DS004100:-/media/data/eeg/ds004100}" \
    --jobs "$WORKERS" \
    --out-csv "$OUTPUT_DIR/ds004100_comprehensive_benchmark.csv" \
    --out-html "$OUTPUT_DIR/ds004100_comprehensive_report.html" \
    --out-md "${REPO_ROOT}/docs/ds004100_comprehensive_benchmark_report.md"

echo ""
echo "======================================================================"
echo "   Benchmark Finished! Report generated."
echo "======================================================================"
