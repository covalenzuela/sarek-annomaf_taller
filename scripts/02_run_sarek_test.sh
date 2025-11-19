#!/usr/bin/env bash
set -euo pipefail

# 02_run_sarek_test.sh (overwrite mode SIN nextflow.config)
# Ejecuta nf-core/sarek con el perfil de prueba y detecta el runtime:
# docker > podman > apptainer > singularity > conda
# Escribe report/trace/timeline con NOMBRES FIJOS y fuerza sobrescritura
# usando -c <(printf ...) para no depender de un archivo nextflow.config.
#
# Uso:
#   bash scripts/02_run_sarek_test.sh
# Variables opcionales:
#   OUTDIR=/ruta/custom/results_test_sarek
#   NXF_VER=25.10.0
#   RESUME=1                # agrega -resume si está definida

# Workspace del taller
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

# Cache para Singularity (recomendado)
if [[ "$RUNTIME" == "singularity" ]]; then
  export SINGULARITY_CACHEDIR="${SINGULARITY_CACHEDIR:-$HOME/.singularity}"
  export NXF_SINGULARITY_CACHEDIR="${NXF_SINGULARITY_CACHEDIR:-$SINGULARITY_CACHEDIR}"
  mkdir -p "$SINGULARITY_CACHEDIR"
fi

# Nextflow recomendado
export NXF_VER="${NXF_VER:-25.10.0}"

# OUTDIR y artefactos
OUTDIR="${OUTDIR:-$HOME/sarek_taller/results_test_sarek}"
mkdir -p "$OUTDIR/pipeline_info"

# -resume opcional
RESUME_FLAG=""
[[ -n "${RESUME:-}" ]] && RESUME_FLAG="-resume"

echo ">>> Ejecutando nf-core/sarek (test) en $OUTDIR (overwrite activado) ..."
nextflow run nf-core/sarek \
  -profile "$PROFILE" \
  --outdir "$OUTDIR" \
  -work-dir "$HOME/sarek_taller/work" \
  -with-report   "$OUTDIR/pipeline_info/execution_report.html" \
  -with-trace    "$OUTDIR/pipeline_info/trace.txt" \
  -with-timeline "$OUTDIR/pipeline_info/timeline.html" \
  -c <(printf '%s\n' \
        'report.overwrite   = true' \
        'timeline.overwrite = true' \
        'trace.overwrite    = true') \
  ${RESUME_FLAG}

echo
echo '>>> Ejecución completada. Estructura de resultados (primeros niveles):'
find "$OUTDIR" -maxdepth 3 -type f | sed -n '1,80p' || true
