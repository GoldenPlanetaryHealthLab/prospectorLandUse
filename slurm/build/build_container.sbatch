#!/usr/bin/env bash
#SBATCH --job-name=build-landuse
#SBATCH --partition=hsph
#SBATCH --cpus-per-task=16
#SBATCH --mem=18G
#SBATCH --time=06:00:00
#SBATCH --output=/n/holylabs/LABS/cgolden_lab/Lab/frontier/works/prospectors/prospectorLandUse/slurm/build/logs/build_%j.out
#SBATCH --error=/n/holylabs/LABS/cgolden_lab/Lab/frontier/works/prospectors/prospectorLandUse/slurm/build/logs/build_%j.err
#SBATCH --mail-type=START,END,FAIL
#SBATCH --mail-user=aaaapr3lk7gfdswioulcmvi3te@harvard.org.slack.com

set -euo pipefail

PROJECT_ROOT="/n/holylabs/LABS/cgolden_lab/Lab/frontier/works/prospectors/prospectorLandUse"
DOCKERFILE="${PROJECT_ROOT}/.devcontainer/Dockerfile"
BUILD_CONTEXT="${PROJECT_ROOT}"
IMAGE_DIR="${PROJECT_ROOT}/.devcontainer"
IMAGE_OUT="${IMAGE_DIR}/prospector-landuse-amd64.sif"
LOG_DIR="${PROJECT_ROOT}/slurm/build/logs"
CACHE_DIR="${PROJECT_ROOT}/.apptainer-cache"
TMP_DIR="/tmp/${USER}-apptainer-${SLURM_JOB_ID:-manual}"

mkdir -p "$LOG_DIR" "$IMAGE_DIR" "$CACHE_DIR" "$TMP_DIR"

export APPTAINER_CACHEDIR="$CACHE_DIR"
export SINGULARITY_CACHEDIR="$CACHE_DIR"
export APPTAINER_TMPDIR="$TMP_DIR"
export SINGULARITY_TMPDIR="$TMP_DIR"

export XDG_RUNTIME_DIR
XDG_RUNTIME_DIR="$(mktemp -d "${TMP_DIR}/xdg.XXXXXX")"

cleanup() {
  if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" ]]; then
    rm -rf "$XDG_RUNTIME_DIR"
  fi
}
trap cleanup EXIT

section() {
  echo
  echo "================================================================"
  echo "$1"
  echo "================================================================"
  date
}

section "Job information"
echo "Job ID: ${SLURM_JOB_ID:-manual}"
echo "Host: $(hostname)"
echo "Project root: $PROJECT_ROOT"
echo "Dockerfile: $DOCKERFILE"
echo "Build context: $BUILD_CONTEXT"
echo "Output image: $IMAGE_OUT"

section "Singularity version"
singularity --version

section "Input checks"
test -f "$DOCKERFILE"
ls -lh "$DOCKERFILE"
du -sh "$PROJECT_ROOT" || true

section "Build container from Dockerfile"
cd "$BUILD_CONTEXT"

singularity build --force --oci "$IMAGE_OUT" "$DOCKERFILE"

section "Inspect built image"
ls -lh "$IMAGE_OUT"
singularity inspect "$IMAGE_OUT" || true

section "Done"
echo "Built image: $IMAGE_OUT"
