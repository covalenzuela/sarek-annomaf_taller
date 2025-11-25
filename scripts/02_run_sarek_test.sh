#!/usr/bin/env bash
set -euo pipefail

# 02_run_sarek_test.sh
# Ejecuta nf-core/sarek con el perfil de prueba,
# usando el entorno LOCAL del repo (activate_env.sh).

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

cd "$BASE_DIR"
echo ">>> Carpeta de trabajo del taller: $BASE_DIR"

# Activar entorno local
if [[ -f "$BASE_DIR/activate_env.sh" ]]; then
  # shellcheck source=/dev/null
  source "$BASE_DIR/activate_env.sh"
else
  echo "[ERROR] No se encontró activate_env.sh."
  echo "        Ejecuta primero: bash scripts/01_install_java_nextflow.sh"
  exit 1
fi

echo ">>> Entorno activo:"
echo "    JAVA_HOME = ${JAVA_HOME:-no_definido}"
echo "    NXF_HOME  = ${NXF_HOME:-no_definido}"
echo "    NXF_VER   = ${NXF_VER:-no_definido}"
echo

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

# Cache para Singularity/Apptainer
if [[ "$RUNTIME" == "singularity" || "$RUNTIME" == "apptainer" ]]; then
  export SINGULARITY_CACHEDIR="${SINGULARITY_CACHEDIR:-$BASE_DIR/.singularity}"
  export APPTAINER_CACHEDIR="${APPTAINER_CACHEDIR:-$BASE_DIR/.apptainer}"
  mkdir -p "$SINGULARITY_CACHEDIR" "$APPTAINER_CACHEDIR"
fi

# Nextflow recomendado (puede venir de activate_env.sh)
export NXF_VER="${NXF_VER:-25.10.0}"

OUTDIR="${OUTDIR:-$BASE_DIR/output/results_test_sarek}"
mkdir -p "$OUTDIR/pipeline_info"
mkdir -p "$BASE_DIR/work"

RESUME_FLAG=""
[[ -n "${RESUME:-}" ]] && RESUME_FLAG="-resume"

echo ">>> Ejecutando nf-core/sarek (test) en $OUTDIR (overwrite activado) ..."
nextflow run nf-core/sarek \
  -profile "$PROFILE" \
  --outdir "$OUTDIR" \
  -work-dir "$BASE_DIR/work" \
  -with-report   "$OUTDIR/pipeline_info/execution_report.html" \
  -with-trace    "$OUTDIR/pipeline_info/trace.txt" \
  -with-timeline "$OUTDIR/pipeline_info/timeline.html" \
  -c <(printf '%s\n' \
        'report.overwrite   = true' \
        'timeline.overwrite = true' \
        'trace.overwrite    = true') \
  ${RESUME_FLAG}

echo
echo '>>> Ejecución completada. Algunos archivos de salida:'
find "$OUTDIR" -maxdepth 3 -type f | sed -n '1,50p' || true
