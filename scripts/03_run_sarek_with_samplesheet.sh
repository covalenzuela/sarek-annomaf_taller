#!/usr/bin/env bash
set -euo pipefail

# Script para ejecutar nf-core/sarek con un samplesheet propio.

cd "$(dirname "$0")/.."   # raíz del repo
mkdir -p "$HOME/sarek_taller"
cd "$HOME/sarek_taller"

SAMPLESHEET="${1:-samplesheet.csv}"
OUTDIR="${2:-results_germline}"

if [[ ! -f "$SAMPLESHEET" ]]; then
  echo "[ERROR] No se encontró el archivo $SAMPLESHEET"
  echo "Crea uno (p.ej. desde notebooks/01_sarek_from_zero.md) o pásalo como argumento:"
  echo "  bash scripts/03_run_sarek_with_samplesheet.sh ruta/a/mi_samplesheet.csv"
  exit 1
fi

# Detectar motor
PROFILE=""
if command -v docker >/dev/null 2>&1; then
  PROFILE="docker"
elif command -v podman >/dev/null 2>&1; then
  PROFILE="podman"
elif command -v apptainer >/dev/null 2>&1; then
  PROFILE="apptainer"
else
  PROFILE="conda"
fi

echo ">>> Usando perfil: $PROFILE"
echo ">>> Usando samplesheet: $SAMPLESHEET"
echo ">>> Outdir: $OUTDIR"

export NXF_VER=25.10.0

nextflow run nf-core/sarek   --input "$SAMPLESHEET"   --genome GATK.GRCh38   --outdir "$OUTDIR"   -profile "$PROFILE"

echo ">>> Listo. Revisa $OUTDIR."
