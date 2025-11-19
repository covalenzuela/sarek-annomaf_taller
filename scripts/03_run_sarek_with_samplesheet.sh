#!/usr/bin/env bash
set -euo pipefail

# 03_run_sarek_with_samplesheet.sh
# Ejecuta nf-core/sarek en modo GERMINAL o SOMÁTICO con datasets livianos.
# - Descarga FASTQ (idempotente) con verificación (gzip + estructura FASTQ).
# - Genera samplesheets válidos para Sarek 3.x.
# - Crea un params.yaml único por ejecución (sin arrays raros).
# - Detecta runtime: docker > podman > apptainer > singularity > conda.
# - Aísla el workdir y el caché de Nextflow por modo (paralelismo sin locks).
#
# Uso:
#   bash scripts/03_run_sarek_with_samplesheet.sh germinal
#   bash scripts/03_run_sarek_with_samplesheet.sh somatico
#
# Variables opcionales:
#   OUTDIR=<ruta>           # por defecto: ~/sarek_taller/results_germline|results_somatic
#   RESUME=1                # agrega -resume
#   GENOME=GATK.GRCh38      # alias soportado por Sarek
#   TOOLS="haplotypecaller" # germinal (minúsculas, separado por comas si varias)
#   TOOLS="mutect2"         # somático (por defecto ponemos mutect2)
#   ALIGNER="bwa-mem2"      # aliner a gusto (string simple)
#   ANNOTATORS="snpeff"     # 'snpeff', 'vep' o 'vep,snpeff' (activa flags en params.yaml)
#   WORK_SUBDIR=<nombre>    # para forzar subcarpeta de work (ej: work_custom)
#   NXF_HOME_ALT=<dir>      # para forzar caché Nextflow alterno (ej: ~/.nextflow_custom)
#   NXF_VER=25.10.0         # versión mínima recomendada de Nextflow
#   MAX_RETRIES=3           # reintentos en descargas
#   VERIFY_FASTQ=0|1        # 1 = verificar gzip+FASTQ (por defecto), 0 = omitir verificación
#
# Notas:
# - Por defecto, este script elige WORK_SUBDIR y NXF_HOME por MODO:
#     germinal -> work_germline   y  ~/.nextflow_germline
#     somatico -> work_somatic    y  ~/.nextflow_somatic
#   (Puedes sobrescribirlos con WORK_SUBDIR y/o NXF_HOME_ALT.)
#
# - Los reportes (report/timeline/trace) se guardan con timestamp en:
#     <OUTDIR>/pipeline_info/

MODE="${1:-}"
if [[ -z "${MODE}" ]]; then
  echo "Uso: bash $0 <germinal|somatico>"
  exit 1
fi

# Normalizamos MODE a minúsculas
MODE="${MODE,,}"

# ---------- Rutas base ----------
WORKROOT="$HOME/sarek_taller"
DATADIR="$WORKROOT/data"
mkdir -p "$DATADIR"
cd "$WORKROOT"

# ---------- Runtime detection ----------
detect_runtime() {
  if command -v docker >/dev/null 2>&1; then
    echo "docker"
  elif command -v podman >/dev/null 2>&1; then
    echo "podman"
  elif command -v apptainer >/dev/null 2>&1; then
    echo "apptainer"
  elif command -v singularity >/dev/null 2>&1; then
    echo "singularity"
  elif command -v conda >/dev/null 2>&1; then
    echo "conda"
  else
    echo ""
  fi
}
RUNTIME="$(detect_runtime)"
if [[ -z "$RUNTIME" ]]; then
  echo "[ERROR] No hay docker/podman/apptainer/singularity/conda en PATH."
  exit 1
fi
echo ">>> Runtime detectado: $RUNTIME"

# Caché singularity recomendado
if [[ "$RUNTIME" == "singularity" || "$RUNTIME" == "apptainer" ]]; then
  export SINGULARITY_CACHEDIR="${SINGULARITY_CACHEDIR:-$HOME/.singularity}"
  mkdir -p "$SINGULARITY_CACHEDIR"
fi

# ---------- Versiones / flags globales ----------
export NXF_VER="${NXF_VER:-25.10.0}"
RESUME_FLAG=""
[[ -n "${RESUME:-}" ]] && RESUME_FLAG="-resume"

GENOME="${GENOME:-GATK.GRCh38}"
MAX_RETRIES="${MAX_RETRIES:-3}"
VERIFY_FASTQ="${VERIFY_FASTQ:-1}"   # 1 = verifica; 0 = omite verificación

# ---------- Helpers de verificación / descarga ----------

verify_fastq() {
  local f="$1"

  # Permite omitir la verificación si VERIFY_FASTQ=0
  if [[ "$VERIFY_FASTQ" != "1" ]]; then
    echo "[SKIP] Verificación de FASTQ desactivada para $f (VERIFY_FASTQ=0)"
    return 0
  fi

  echo ">>> Verificando $f"
  if ! gzip -t "$f" 2>/dev/null; then
    echo "[ERR] gzip corrupto en $f"; return 1
  fi
  local head4 L1 L3
  head4="$(zcat "$f" 2>/dev/null | sed -n '1,4p' || true)"
  L1="$(printf '%s\n' "$head4" | sed -n '1p')"
  L3="$(printf '%s\n' "$head4" | sed -n '3p')"
  if [[ "${L1:0:1}" != "@" || "${L3:0:1}" != "+" ]]; then
    echo "[ERR] Estructura FASTQ inválida en $f"; return 1
  fi
  echo "[OK] $f pasó verificación"
}

_fetch() {
  local url="$1"; local out="$2"
  if command -v aria2c >/dev/null 2>&1; then
    aria2c -x 8 -s 8 -c --retry-wait=5 --max-tries=5 -o "$(basename "$out")" -d "$(dirname "$out")" "$url"
  else
    curl -L -C - --retry 5 --retry-delay 5 -o "$out" "$url"
  fi
}

dl() {
  local url="$1"; local out="$2"
  if [[ -s "$out" ]]; then
    echo "[skip] $out"
    if verify_fastq "$out"; then return 0; else rm -f "$out"; fi
  fi
  local attempt=1
  while (( attempt <= MAX_RETRIES )); do
    echo "[get] ($attempt/$MAX_RETRIES) $url -> $out"
    _fetch "$url" "$out" || true
    if verify_fastq "$out"; then return 0; fi
    echo "[WARN] Descarga inválida: $out"; rm -f "$out"; attempt=$((attempt+1))
  done
  echo "[FATAL] No se pudo obtener FASTQ válido: $out"; exit 2
}

# ---------- Helpers de validación de flags (input) ----------

# Normaliza a minúsculas y sin espacios alrededor de comas
_normalize_csv() {
  local raw="$1"
  raw="${raw,,}"      # minúsculas
  raw="${raw// /}"    # quita espacios
  echo "$raw"
}

validate_mode() {
  case "$MODE" in
    germinal|germ|somatico|somatic) ;;
    *)
      echo "[ERROR] Modo no reconocido: '$MODE' (usa 'germinal' o 'somatico')" >&2
      exit 1
      ;;
  esac
}

validate_genome() {
  # Lista breve de alias típicos; si no está, solo avisamos.
  local known=(
    "GATK.GRCh38" "GATK.GRCh37"
    "GRCh38" "GRCh37"
  )
  local g="$GENOME" found="0"
  for k in "${known[@]}"; do
    if [[ "$g" == "$k" ]]; then
      found="1"; break
    fi
  done
  if [[ "$found" == "0" ]]; then
    echo "[WARN] GENOME='$GENOME' no está en la lista corta de alias típicos de Sarek 3.x."
    echo "       Revisa la documentación de nf-core/sarek si ves errores relacionados al genome."
  fi
}

validate_tools() {
  local list="$1"
  if [[ -z "$list" ]]; then
    echo "[ERROR] TOOLS no puede estar vacío. Ejemplos: 'haplotypecaller' o 'mutect2'." >&2
    exit 1
  fi
  IFS=',' read -ra arr <<< "$list"
  for t in "${arr[@]}"; do
    if [[ -z "$t" ]]; then
      echo "[ERROR] TOOLS contiene una entrada vacía (¿dos comas seguidas?)." >&2
      exit 1
    fi
    if [[ "$t" =~ [^a-z0-9._-] ]]; then
      echo "[ERROR] TOOLS contiene caracteres inválidos: '$t' (usa minúsculas, dígitos, '.', '_' o '-')." >&2
      exit 1
    fi
  done
}

validate_aligner() {
  local a="$1"
  if [[ -z "$a" ]]; then
    echo "[ERROR] ALIGNER no puede estar vacío." >&2
    exit 1
  fi
  if [[ "$a" =~ [^a-z0-9._-] ]]; then
    echo "[ERROR] ALIGNER contiene caracteres inválidos: '$a'." >&2
    exit 1
  fi
}

# Esta función deja seteados SNP_EFF y VEP según ANNOTATORS_CANON
parse_and_validate_annotators() {
  local list="$1"
  SNP_EFF="false"
  VEP="false"

  [[ -z "$list" ]] && return 0   # sin anotadores es válido

  IFS=',' read -ra arr <<< "$list"
  for a in "${arr[@]}"; do
    case "$a" in
      snpeff)
        SNP_EFF="true"
        ;;
      vep)
        VEP="true"
        ;;
      "")
        echo "[ERROR] ANNOTATORS contiene una entrada vacía (¿dos comas seguidas?)." >&2
        exit 1
        ;;
      *)
        echo "[ERROR] ANNOTATORS contiene valor no soportado: '$a'." >&2
        echo "        Usa solo: 'snpeff', 'vep' o 'vep,snpeff'." >&2
        exit 1
        ;;
    esac
  done
}

# ---------- Params (yaml): normalización y validación ----------

# Set por modo (y puedes override con TOOLS/ALIGNER vía env)
if [[ "$MODE" == "germinal" || "$MODE" == "germ" ]]; then
  TOOLS_DEFAULT="haplotypecaller"
else
  TOOLS_DEFAULT="mutect2"
fi

# Normalizamos TOOLS / ALIGNER / ANNOTATORS a minúsculas y CSV limpio
TOOLS_ENV="${TOOLS:-$TOOLS_DEFAULT}"
TOOLS_VAL="$(_normalize_csv "$TOOLS_ENV")"

ALIGNER_ENV="${ALIGNER:-bwa-mem2}"
ALIGNER_VAL="${ALIGNER_ENV,,}"

ANNOTATORS_ENV="${ANNOTATORS:-}"
ANNOTATORS_CANON="$(_normalize_csv "$ANNOTATORS_ENV")"

# Validamos flags de entrada antes de seguir
validate_mode
validate_genome
validate_tools "$TOOLS_VAL"
validate_aligner "$ALIGNER_VAL"
parse_and_validate_annotators "$ANNOTATORS_CANON"
# En este punto SNP_EFF y VEP ya están seteados ("true"/"false")

# ---------- Workdirs / caches según MODO ----------
timestamp="$(date +%F_%H-%M-%S)"

if [[ "$MODE" == "germinal" || "$MODE" == "germ" ]]; then
  OUTDIR="${OUTDIR:-$WORKROOT/results_germline}"
  WORK_SUBDIR="${WORK_SUBDIR:-work_germline}"
  NXF_HOME="${NXF_HOME_ALT:-$HOME/.nextflow_germline}"
else
  OUTDIR="${OUTDIR:-$WORKROOT/results_somatic}"
  WORK_SUBDIR="${WORK_SUBDIR:-work_somatic}"
  NXF_HOME="${NXF_HOME_ALT:-$HOME/.nextflow_somatic}"
fi
export NXF_HOME  # aísla el .nextflow (locks/caches) por modo

WORKDIR="$WORKROOT/$WORK_SUBDIR"
mkdir -p "$WORKDIR" "$OUTDIR"
INFO_DIR="$OUTDIR/pipeline_info"
mkdir -p "$INFO_DIR"

REPORT_PATH="$INFO_DIR/execution_report_${timestamp}.html"
TIMELINE_PATH="$INFO_DIR/timeline_${timestamp}.html"
TRACE_PATH="$INFO_DIR/trace_${timestamp}.txt"

# ---------- Dataset + samplesheet ----------
case "$MODE" in
  germinal|germ)
    echo ">>> Modo GERMINAL"
    FQ1="$DATADIR/SRR622461_1.fastq.gz"
    FQ2="$DATADIR/SRR622461_2.fastq.gz"
    dl "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR622/SRR622461/SRR622461_1.fastq.gz" "$FQ1"
    dl "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR622/SRR622461/SRR622461_2.fastq.gz" "$FQ2"

    SAMPLESHEET="$WORKROOT/samplesheet_germinal.csv"
    cat > "$SAMPLESHEET" <<EOF
patient,sample,lane,fastq_1,fastq_2,sex,status
NA12878,NA12878,1,$FQ1,$FQ2,XX,0
EOF
  ;;

  somatico|somatic)
    echo ">>> Modo SOMÁTICO"
    N1="$DATADIR/SRR1663561_1.fastq.gz"
    N2="$DATADIR/SRR1663561_2.fastq.gz"
    T1="$DATADIR/SRR1663550_1.fastq.gz"
    T2="$DATADIR/SRR1663550_2.fastq.gz"
    dl "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR166/001/SRR1663561/SRR1663561_1.fastq.gz" "$N1"
    dl "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR166/001/SRR1663561/SRR1663561_2.fastq.gz" "$N2"
    dl "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR166/000/SRR1663550/SRR1663550_1.fastq.gz" "$T1"
    dl "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR166/000/SRR1663550/SRR1663550_2.fastq.gz" "$T2"

    SAMPLESHEET="$WORKROOT/samplesheet_somatic.csv"
    cat > "$SAMPLESHEET" <<EOF
patient,sample,lane,fastq_1,fastq_2,sex,status
P01,NORMAL,1,$N1,$N2,XX,0
P01,TUMOR,1,$T1,$T2,XX,1
EOF
  ;;

  *)
    echo "[ERROR] Modo no reconocido tras normalización: $MODE (usa 'germinal' o 'somatico')"
    exit 1
  ;;
esac

# ---------- Escribir params.yaml ----------
PARAMS_FILE="$WORKROOT/params.yaml"

cat > "$PARAMS_FILE" <<EOF
# Archivo generado por 03_run_sarek_with_samplesheet.sh
input: "$SAMPLESHEET"
genome: "$GENOME"
aligner: "$ALIGNER_VAL"
tools: "$TOOLS_VAL"
snpeff: $SNP_EFF
vep: $VEP
EOF

# Si activaste snpeff/vep, añadimos defaults razonables
if [[ "$SNP_EFF" == "true" ]]; then
  cat >> "$PARAMS_FILE" <<'EOF'
snpeff_genome: GRCh38
snpeff_db: 105
EOF
fi
if [[ "$VEP" == "true" ]]; then
  cat >> "$PARAMS_FILE" <<'EOF'
vep_cache_version: 114
vep_species: homo_sapiens
EOF
fi

echo ">>> Config efectiva:"
echo "    MODE        = $MODE"
echo "    GENOME      = $GENOME"
echo "    TOOLS       = $TOOLS_VAL"
echo "    ALIGNER     = $ALIGNER_VAL"
echo "    ANNOTATORS  = ${ANNOTATORS_CANON:-<none>}"
echo "    SNP_EFF?    = $SNP_EFF"
echo "    VEP?        = $VEP"
echo "    VERIFY_FASTQ= $VERIFY_FASTQ"

echo ">>> params.yaml -> $PARAMS_FILE"
echo ">>> samplesheet -> $SAMPLESHEET"
echo ">>> work-dir    -> $WORKDIR"
echo ">>> outdir      -> $OUTDIR"
echo ">>> NXF_HOME    -> $NXF_HOME"

# ---------- Ejecutar Sarek ----------
# Mapear RUNTIME a perfil nf-core válido (apptainer usa perfil singularity)
case "$RUNTIME" in
  apptainer) PROFILE="singularity" ;;
  *)         PROFILE="$RUNTIME" ;;
esac

CMD=( nextflow run nf-core/sarek
  -params-file "$PARAMS_FILE"
  --outdir "$OUTDIR"
  -work-dir "$WORKDIR"
  -profile "$PROFILE"
  -with-report   "$REPORT_PATH"
  -with-timeline "$TIMELINE_PATH"
  -with-trace    "$TRACE_PATH"
)

# OJO: ya no pasamos --somatic; Sarek infiere somático por samplesheet/tools.

if [[ -n "$RESUME_FLAG" ]]; then
  CMD+=( "$RESUME_FLAG" )
fi

echo ">>> Lanzando:"
printf ' %q' "${CMD[@]}"; echo
"${CMD[@]}"

echo ">>> Listo. MultiQC (si aplica):"
find "$OUTDIR" -type f -name 'multiqc_report.html' | sed -n '1,3p' || true
