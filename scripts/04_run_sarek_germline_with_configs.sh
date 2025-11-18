#!/usr/bin/env bash
set -euo pipefail

# 04_run_sarek_germline_with_configs.sh (robusto como 03)
# Ejecuta nf-core/sarek en modo GERMINAL creando:
#  - Descarga idempotente y verificada de FASTQ GIAB (NA12878 recortado)
#  - samplesheet_germinal.csv (Sarek 3.x: patient,sample,lane,fastq_1,fastq_2,sex,status)
#  - params.yaml (parámetros del pipeline: genome, aligner, tools, etc.)
#  - nextflow.config (config de recursos/perfiles, sin parámetros de pipeline)
#
# Uso:
#   bash scripts/04_run_sarek_germline_with_configs.sh
#
# Variables opcionales:
#   OUTDIR=results_germline_custom
#   GENOME=GATK.GRCh38
#   ALIGNER=bwa-mem2
#   TOOLS="HaplotypeCaller,DeepVariant"
#   PROFILE=docker
#   RESUME=1
#   NXF_VER=25.10.0
#   MAX_RETRIES=3
#   FORCE_REDOWNLOAD=1
#
GIAB_R1_URL="https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR622/SRR622461/SRR622461_1.fastq.gz"
GIAB_R2_URL="https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR622/SRR622461/SRR622461_2.fastq.gz"

WORKDIR="$HOME/sarek_taller"
DATADIR="$WORKDIR/data"
mkdir -p "$DATADIR"
cd "$WORKDIR"

detect_profile() {
  if command -v docker >/dev/null 2>&1; then
    echo "docker"
  elif command -v podman >/dev/null 2>&1; then
    echo "podman"
  elif command -v apptainer >/dev/null 2>&1; then
    echo "apptainer"
  else
    echo "conda"
  fi
}
PROFILE="${PROFILE:-$(detect_profile)}"

export NXF_VER="${NXF_VER:-25.10.0}"

RESUME_FLAG=""
[[ -n "${RESUME:-}" ]] && RESUME_FLAG="-resume"

OUTDIR="${OUTDIR:-results_germline}"
GENOME="${GENOME:-GATK.GRCh38}"
ALIGNER="${ALIGNER:-bwa-mem2}"
TOOLS_CSV="${TOOLS:-HaplotypeCaller,DeepVariant}"
MAX_RETRIES="${MAX_RETRIES:-3}"

verify_fastq() {
  local f="$1"
  echo ">>> Verificando $f"
  if ! gzip -t "$f" 2>/dev/null; then
    echo "[ERR] gzip corrupto en $f"
    return 1
  fi
  local head4 L1 L3
  head4="$(zcat "$f" 2>/dev/null | sed -n '1,4p' || true)"
  L1="$(printf '%s\n' "$head4" | sed -n '1p')"
  L3="$(printf '%s\n' "$head4" | sed -n '3p')"
  if [[ "${L1:0:1}" != "@" || "${L3:0:1}" != "+" ]]; then
    echo "[ERR] Estructura FASTQ inválida en $f"
    return 1
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

  if [[ -z "${FORCE_REDOWNLOAD:-}" && -s "$out" ]]; then
    echo "[skip] $out"
    if verify_fastq "$out"; then
      return 0
    else
      echo "[WARN] Archivo existente inválido, se re-descargará: $out"
      rm -f "$out"
    fi
  fi

  local attempt=1
  while (( attempt <= MAX_RETRIES )); do
    echo "[get] ($attempt/$MAX_RETRIES) $url -> $out"
    _fetch "$url" "$out" || true
    if verify_fastq "$out"; then
      return 0
    fi
    echo "[WARN] Descarga inválida: $out"
    rm -f "$out"
    attempt=$((attempt+1))
  done

  echo "[FATAL] No se pudo obtener un FASTQ válido: $out"
  exit 2
}

echo ">>> Descargando dataset germinal (si falta / o inválido)"
FQ1="$DATADIR/SRR622461_1.fastq.gz"
FQ2="$DATADIR/SRR622461_2.fastq.gz"
dl "$GIAB_R1_URL" "$FQ1"
dl "$GIAB_R2_URL" "$FQ2"

SAMPLESHEET="$WORKDIR/samplesheet_germinal.csv"
cat > "$SAMPLESHEET" <<EOF
patient,sample,lane,fastq_1,fastq_2,sex,status
NA12878,NA12878,1,$FQ1,$FQ2,XX,0
EOF
echo ">>> Samplesheet: $SAMPLESHEET"
cat "$SAMPLESHEET"

PARAMS_FILE="$WORKDIR/params.yaml"
TOOLS_YAML=$(echo "$TOOLS_CSV" | awk -v RS=',' '{gsub(/^[[:space:]]+|[[:space:]]+$/,""); print "- "$0}')

cat > "$PARAMS_FILE" <<EOF
# Parámetros del pipeline nf-core/sarek (usar con -params-file)
input: "$SAMPLESHEET"
genome: "$GENOME"

aligner: "$ALIGNER"

tools:
$TOOLS_YAML

# Ejemplos adicionales:
# save_mapped: true
# save_output_as_bam: true
# use_gatk_spark: false
# joint_germline: true
# wes: true
# intervals: "/ruta/a/targets.bed"
# max_cpus: 4
EOF
echo ">>> params.yaml creado en $PARAMS_FILE"
sed -n '1,120p' "$PARAMS_FILE"

NFCONFIG="$WORKDIR/nextflow.config"
cat > "$NFCONFIG" <<'EOF'
// nextflow.config local para Sarek (recursos/perfiles). No colocar "params" aquí.
profiles {
  docker {
    process.container = null
    docker.enabled = true
  }
  podman {
    process.container = null
    podman.enabled = true
  }
  apptainer {
    process.container = null
    apptainer.enabled = true
  }
  conda {
    conda.enabled = true
  }
}

/*
process {
  withName: BWA_MEM2_MEM { cpus = 4; memory = '8 GB'; time = '6 h' }
  withName: GATK_HAPLOTYPECALLER { cpus = 4; memory = '12 GB'; time = '12 h' }
}
*/

workDir = "${HOME}/sarek_taller/work"
EOF
echo ">>> nextflow.config creado en $NFCONFIG"
sed -n '1,120p' "$NFCONFIG"

echo ">>> Lanzando Sarek germinal con perfil '$PROFILE'"
nextflow run nf-core/sarek \
  -profile "$PROFILE" \
  -params-file "$PARAMS_FILE" \
  --outdir "$OUTDIR" \
  $RESUME_FLAG

echo ">>> Listo. Revisa $OUTDIR"
