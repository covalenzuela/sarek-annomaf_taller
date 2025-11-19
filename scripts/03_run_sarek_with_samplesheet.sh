#!/usr/bin/env bash
set -euo pipefail

# 03_run_sarek_with_samplesheet.sh (sin nextflow.config)
# Ejecuta nf-core/sarek en modo GERMINAL o SOMÁTICO con datasets livianos.
# - Descarga FASTQ con verificación (idempotente).
# - Genera samplesheets válidos para Sarek 3.x.
# - Activa anotación opcional (SnpEff / VEP) vía -params-file.
# - Detecta runtime: docker > podman > apptainer > singularity > conda.
#
# Uso:
#   bash scripts/03_run_sarek_with_samplesheet.sh germinal
#   bash scripts/03_run_sarek_with_samplesheet.sh somatico
#
# Variables opcionales:
#   OUTDIR=results_germline   # o results_somatic
#   NXF_VER=25.10.0           # versión mínima recomendada de Nextflow
#   RESUME=1                  # agrega -resume
#   GENOME=GATK.GRCh38        # alias soportado por Sarek
#   MAX_RETRIES=3             # reintentos de descarga
#   ANNOTATORS=snpeff         # 'snpeff', 'vep' o 'vep,snpeff'
#

MODE="${1:-}"
if [[ -z "${MODE}" ]]; then
  echo "Uso: bash $0 <germinal|somatico>"
  exit 1
fi

# --- Rutas ---
WORKDIR="$HOME/sarek_taller"
DATADIR="$WORKDIR/data"
mkdir -p "$DATADIR"
cd "$WORKDIR"

# --- Detección de runtime ---
PROFILE=""
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
  echo "[ERROR] No hay docker/podman/apptainer/singularity/conda en PATH."
  exit 1
fi

PROFILE="$RUNTIME"
# Si es singularity, usar el perfil singularity y cache local
if [[ "$RUNTIME" == "singularity" ]]; then
  export SINGULARITY_CACHEDIR="${SINGULARITY_CACHEDIR:-$HOME/.singularity}"
  mkdir -p "$SINGULARITY_CACHEDIR"
fi

# Asegurar versión de Nextflow
export NXF_VER="${NXF_VER:-25.10.0}"

# Bandera resume
RESUME_FLAG=""
[[ -n "${RESUME:-}" ]] && RESUME_FLAG="-resume"

# Genoma
GENOME="${GENOME:-GATK.GRCh38}"

# Reintentos
MAX_RETRIES="${MAX_RETRIES:-3}"

# ---------- Descarga con verificación ----------
verify_fastq() {
  local f="$1"
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
    echo "[skip] Ya existe $out"
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

# ---------- params.yaml (anotadores) ----------
PARAMS_FILE="$WORKDIR/params_annot.yaml"
cat > "$PARAMS_FILE" <<EOF
snpeff: false
vep: false
use_annotation_cache_keys: true
EOF
if [[ "${ANNOTATORS:-}" =~ (^|,)snpeff($|,) ]]; then
  sed -i 's/^snpeff: false/snpeff: true/' "$PARAMS_FILE"
fi
if [[ "${ANNOTATORS:-}" =~ (^|,)vep($|,) ]]; then
  sed -i 's/^vep: false/vep: true/' "$PARAMS_FILE"
fi

# Helper para -profile (solo si existe)
profile_args=()
if [[ -n "$PROFILE" ]]; then
  profile_args=(-profile "$PROFILE")
fi

# ---------- Flujo principal ----------
case "$MODE" in
  germinal|germ)
    echo ">>> Modo GERMINAL (perfil: ${PROFILE})"
    FQ1="$DATADIR/SRR622461_1.fastq.gz"
    FQ2="$DATADIR/SRR622461_2.fastq.gz"
    dl "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR622/SRR622461/SRR622461_1.fastq.gz" "$FQ1"
    dl "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR622/SRR622461/SRR622461_2.fastq.gz" "$FQ2"

    SAMPLESHEET="$WORKDIR/samplesheet_germinal.csv"
    cat > "$SAMPLESHEET" <<EOF
patient,sample,lane,fastq_1,fastq_2,sex,status
NA12878,NA12878,1,$FQ1,$FQ2,XX,0
EOF

    OUT="${OUTDIR:-results_germline}"; mkdir -p "$OUT"

    nextflow run nf-core/sarek       --input "$SAMPLESHEET"       --genome "$GENOME"       --outdir "$OUT"       -params-file "$PARAMS_FILE"       "${profile_args[@]}"       $RESUME_FLAG
    ;;

  somatico|somatic)
    echo ">>> Modo SOMÁTICO (tumor/normal) (perfil: ${PROFILE})"
    N1="$DATADIR/SRR1663561_1.fastq.gz"
    N2="$DATADIR/SRR1663561_2.fastq.gz"
    T1="$DATADIR/SRR1663550_1.fastq.gz"
    T2="$DATADIR/SRR1663550_2.fastq.gz"

    dl "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR166/001/SRR1663561/SRR1663561_1.fastq.gz" "$N1"
    dl "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR166/001/SRR1663561/SRR1663561_2.fastq.gz" "$N2"
    dl "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR166/000/SRR1663550/SRR1663550_1.fastq.gz" "$T1"
    dl "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR166/000/SRR1663550/SRR1663550_2.fastq.gz" "$T2"

    SAMPLESHEET="$WORKDIR/samplesheet_somatic.csv"
    cat > "$SAMPLESHEET" <<EOF
patient,sample,lane,fastq_1,fastq_2,sex,status
P01,NORMAL,1,$N1,$N2,XX,0
P01,TUMOR,1,$T1,$T2,XX,1
EOF

    OUT="${OUTDIR:-results_somatic}"; mkdir -p "$OUT"

    nextflow run nf-core/sarek       --input "$SAMPLESHEET"       --genome "$GENOME"       --outdir "$OUT"       --somatic       -params-file "$PARAMS_FILE"       "${profile_args[@]}"       $RESUME_FLAG
    ;;

  *)
    echo "[ERROR] Modo no reconocido: $MODE (usa 'germinal' o 'somatico')"
    exit 1
    ;;
esac

echo ">>> Listo."
