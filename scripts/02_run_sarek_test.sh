#!/usr/bin/env bash
set -euo pipefail

# Script para ejecutar nf-core/sarek con el perfil de prueba.
# Detecta el motor de software disponible: docker / podman / apptainer / conda.

cd "$(dirname "$0")/.."   # ir a la raíz del repo
mkdir -p "$HOME/sarek_taller"
cd "$HOME/sarek_taller"

echo ">>> Carpeta de trabajo: $PWD"

# Detectar motor
PROFILE="test"
if command -v docker >/dev/null 2>&1; then
  PROFILE="$PROFILE,docker"
elif command -v podman >/dev/null 2>&1; then
  PROFILE="$PROFILE,podman"
elif command -v apptainer >/dev/null 2>&1; then
  PROFILE="$PROFILE,apptainer"
else
  PROFILE="$PROFILE,conda"
fi

echo ">>> Usando perfil: $PROFILE"

# Asegurar versión adecuada de Nextflow (requerida por Sarek)
export NXF_VER=25.10.0

OUTDIR="results_test_sarek"

echo ">>> Ejecutando nf-core/sarek (test) en $OUTDIR ..."
nextflow run nf-core/sarek   -profile "$PROFILE"   --outdir "$OUTDIR"   -with-report execution_report.html   -with-trace trace.txt   -with-timeline timeline.html

echo
echo '>>> Ejecución completada. Estructura de resultados (primeros niveles):'
find "$OUTDIR" -maxdepth 3 -type f | sed -n '1,80p'
echo
echo '>>> MultiQC HTML:'
find "$OUTDIR" -type f -name 'multiqc_report.html' || echo 'No se encontró MultiQC (revisa la ejecución).'
