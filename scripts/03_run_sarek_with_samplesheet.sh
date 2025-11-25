#!/usr/bin/env bash
set -euo pipefail

# 03_run_sarek_with_samplesheet.sh
# Ejecuta nf-core/sarek en modo GERMINAL a partir de FASTQ locales.
# - El usuario SOLO pasa FASTQ1/FASTQ2, patient, sample (y opcionales).
# - El script genera internamente el samplesheet CSV.
# - Los resultados van a ./output/<sample>_sarek_run/

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

usage() {
  cat <<EOF
Uso (germinal de un solo par FASTQ):

  bash scripts/03_run_sarek_with_samplesheet.sh \\
    --fastq1 R1.fastq.gz \\
    --fastq2 R2.fastq.gz \\
    --patient PATIENT_ID \\
    --sample SAMPLE_ID \\
    [--genome GENOME_ALIAS] \\
    [--engine docker|conda|apptainer|singularity]

Ejemplo:

  bash scripts/03_run_sarek_with_samplesheet.sh \\
    --fastq1 data/NA12878_R1.fastq.gz \\
    --fastq2 data/NA12878_R2.fastq.gz \\
    --patient NA12878 \\
    --sample NA12878 \\
    --genome GRCh38 \\
    --engine docker
EOF
  exit 1
}

FASTQ1=""
FASTQ2=""
PATIENT=""
SAMPLE=""
GENOME="GRCh38"
ENGINE="docker"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fastq1)  FASTQ1="$2"; shift 2 ;;
    --fastq2)  FASTQ2="$2"; shift 2 ;;
    --patient) PATIENT="$2"; shift 2 ;;
    --sample)  SAMPLE="$2"; shift 2 ;;
    --genome)  GENOME="$2"; shift 2 ;;
    --engine)  ENGINE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *)
      echo "[ERROR] Opción desconocida: $1"
      usage
      ;;
  esac
done

if [[ -z "$FASTQ1" || -z "$FASTQ2" || -z "$PATIENT" || -z "$SAMPLE" ]]; then
  echo "[ERROR] Faltan parámetros obligatorios."
  usage
fi

cd "$BASE_DIR"

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

# Comprobar FASTQ
if [[ ! -f "$FASTQ1" ]]; then
  echo "[ERROR] No se encuentra: $FASTQ1"
  exit 1
fi
if [[ ! -f "$FASTQ2" ]]; then
  echo "[ERROR] No se encuentra: $FASTQ2"
  exit 1
fi

mkdir -p "$BASE_DIR/samplesheets"
mkdir -p "$BASE_DIR/output"
mkdir -p "$BASE_DIR/work"

SAMPLESHEET="$BASE_DIR/samplesheets/${SAMPLE}_samplesheet.csv"
OUTDIR="$BASE_DIR/output/${SAMPLE}_sarek_run"

echo ">>> Generando samplesheet: $SAMPLESHEET"
cat > "$SAMPLESHEET" <<EOF
patient,sample,lane,fastq_1,fastq_2,sex,status
$PATIENT,$SAMPLE,1,$FASTQ1,$FASTQ2,XX,0
EOF

echo ">>> Samplesheet generado:"
cat "$SAMPLESHEET"
echo

# Resolver runtime
RUNTIME="$ENGINE"
if [[ "$RUNTIME" != "docker" && "$RUNTIME" != "conda" && \
      "$RUNTIME" != "apptainer" && "$RUNTIME" != "singularity" ]]; then
  echo ">>> --engine no reconocido, detectando automáticamente..."
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
    echo "[ERROR] No se encontró ningún motor (docker/podman/apptainer/singularity/conda)."
    exit 1
  fi
fi

PROFILE="$RUNTIME"

# Cache singularity/apptainer local
if [[ "$RUNTIME" == "singularity" || "$RUNTIME" == "apptainer" ]]; then
  export SINGULARITY_CACHEDIR="${SINGULARITY_CACHEDIR:-$BASE_DIR/.singularity}"
  export APPTAINER_CACHEDIR="${APPTAINER_CACHEDIR:-$BASE_DIR/.apptainer}"
  mkdir -p "$SINGULARITY_CACHEDIR" "$APPTAINER_CACHEDIR"
fi

mkdir -p "$OUTDIR"
INFO_DIR="$OUTDIR/pipeline_info"
mkdir -p "$INFO_DIR"

REPORT_PATH="$INFO_DIR/execution_report.html"
TIMELINE_PATH="$INFO_DIR/timeline.html"
TRACE_PATH="$INFO_DIR/trace.txt"

echo ">>> Ejecutando nf-core/sarek con:"
echo "    Paciente : $PATIENT"
echo "    Muestra  : $SAMPLE"
echo "    FASTQ1   : $FASTQ1"
echo "    FASTQ2   : $FASTQ2"
echo "    Genoma   : $GENOME"
echo "    Perfil   : $PROFILE"
echo "    Outdir   : $OUTDIR"
echo

nextflow run nf-core/sarek \
  -r 3.6.1 \
  --input "$SAMPLESHEET" \
  --genome "$GENOME" \
  --outdir "$OUTDIR" \
  -work-dir "$BASE_DIR/work" \
  -profile "$PROFILE" \
  -with-report   "$REPORT_PATH" \
  -with-timeline "$TIMELINE_PATH" \
  -with-trace    "$TRACE_PATH"

echo
echo ">>> Ejecución finalizada."
echo "    - Samplesheet: $SAMPLESHEET"
echo "    - Resultados : $OUTDIR"
find "$OUTDIR" -maxdepth 3 -type f | sed -n '1,40p' || true
