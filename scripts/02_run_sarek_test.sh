#!/usr/bin/env bash
set -euo pipefail

# 02_run_sarek_test.sh
# Ejecuta nf-core/sarek con el perfil de prueba y detecta el runtime:
# docker > podman > apptainer > singularity > conda
# (si solo hay singularity, usa el perfil 'singularity' de nf-core)
#
# Salidas extra: report, trace, timeline.

# Ir a la raíz del repo y luego al workspace del taller
cd "$(dirname "$0")/.."
mkdir -p "$HOME/sarek_taller"
cd "$HOME/sarek_taller"
echo ">>> Carpeta de trabajo: $PWD"

# Detectar runtime
PROFILE="test"
RUNTIME=""

if command -v docker >/dev/null 2>&1; then
  RUNTIME="docker"
elif command -v podman >/dev/null 2>&1; then
  RUNTIME="podman"
elif command -v apptainer >/dev/null 2>&1; then
  RUNTIME="apptainer"
elif command -v singularity >/dev/null 2>&1; then
  RUNTIME="singularity"
elif command -v conda >/dev/null 2>&1; then
  RUNTIME="conda"
else
  echo "[ERROR] No se encontró docker/podman/apptainer/singularity/conda en PATH."
  exit 1
fi

PROFILE="${PROFILE},${RUNTIME}"
echo ">>> Usando perfil: $PROFILE"

# Si se usa Singularity, define un caché local (recomendado)
if [[ "$RUNTIME" == "singularity" ]]; then
  export SINGULARITY_CACHEDIR="${SINGULARITY_CACHEDIR:-$HOME/.singularity}"
  mkdir -p "$SINGULARITY_CACHEDIR"
fi

# Asegurar versión adecuada de Nextflow (requerida por Sarek)
export NXF_VER="${NXF_VER:-25.10.0}"

OUTDIR="results_test_sarek"

echo ">>> Ejecutando nf-core/sarek (test) en $OUTDIR ..."
nextflow run nf-core/sarek \
  -profile "$PROFILE" \
  --outdir "$OUTDIR" \
  -with-report execution_report.html \
  -with-trace trace.txt \
  -with-timeline timeline.html

echo
echo '>>> Ejecución completada. Estructura de resultados (primeros niveles):'
find "$OUTDIR" -maxdepth 3 -type f | sed -n '1,80p' || true
echo
echo '>>> MultiQC HTML:'
find "$OUTDIR" -type f -name 'multiqc_report.html' || echo 'No se encontró MultiQC (revisa la ejecución).'
