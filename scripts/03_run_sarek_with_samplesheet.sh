#!/usr/bin/env bash
set -euo pipefail

# 03_run_sarek_with_samplesheet.sh
# Ejecuta nf-core/sarek en modo GERMINAL o SOMATICO con datasets livianos de ejemplo.
# - Descarga los FASTQ si no existen (idempotente) con validación de integridad.
# - Genera un samplesheet acorde a Sarek 3.x (incluye 'patient','lane','status').
# - Detecta el motor (docker/podman/apptainer/conda).
#
# Uso:
#   bash scripts/03_run_sarek_with_samplesheet.sh germinal
#   bash scripts/03_run_sarek_with_samplesheet.sh somatico
#
# Variables opcionales:
#   OUTDIR=results_germline   # o results_somatic
#   NXF_VER=25.10.0           # versión de Nextflow a usar
#   RESUME=1                  # si está seteado, agrega -resume
#   GENOME=GATK.GRCh38        # alias soportado por Sarek (o setea uno propio)
#   MAX_RETRIES=3             # veces a reintentar descargas dañadas
#

MODE="${1:-}"
if [[ -z "${MODE}" ]]; then
  echo "Uso: bash $0 <germinal|somatico>"
  exit 1
fi

# --- Configuración general ---
WORKDIR="$HOME/sarek_taller"
DATADIR="$WORKDIR/data"
mkdir -p "$DATADIR"
cd "$WORKDIR"

### NUEVO: archivo de configuración de recursos para WSL
NF_CONFIG="${NF_CONFIG:-$WORKDIR/wsl_resources.config}"

cat > "$NF_CONFIG" <<'EOF'
process {
  // Ejecutar local dentro de WSL
  executor = 'local'

  // Nº máximo de procesos en paralelo en toda la pipeline
  maxForks = 2

  // Recursos por proceso (valores por defecto)
  cpus   = 1
  memory = '3 GB'
  time   = '12h'

  // Techos globales aproximados
  maxCpus   = 2
  maxMemory = '6 GB'
}
EOF
### FIN NUEVO

# Detectar motor de ejecución
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

# Asegurar Nextflow versión suficiente
export NXF_VER="${NXF_VER:-25.10.0}"

# Bandera resume
RESUME_FLAG=""
if [[ "${RESUME:-}" != "" ]]; then
  RESUME_FLAG="-resume"
fi

# Genoma por defecto
GENOME="${GENOME:-GATK.GRCh38}"

# Reintentos de descarga
MAX_RETRIES="${MAX_RETRIES:-3}"

# ---------- Utilidades de descarga y verificación ----------

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
  local url="$1"; shift
  local out="$1"; shift

  if command -v aria2c >/dev/null 2>&1; then
    aria2c -x 8 -s 8 -c --retry-wait=5 --max-tries=5 -o "$(basename "$out")" -d "$(dirname "$out")" "$url"
  else
    curl -L -C - --retry 5 --retry-delay 5 -o "$out" "$url"
  fi
}

dl() {
  local url="$1"
  local out="$2"

  if [[ -s "$out" ]]; then
    echo "[skip] Ya existe $out"
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

# ---------- Flujo principal ----------

case "$MODE" in
  germinal|germ)
    echo ">>> Modo GERMINAL"

    FQ1="$DATADIR/SRR622461_1.fastq.gz"
    FQ2="$DATADIR/SRR622461_2.fastq.gz"
    dl "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR622/SRR622461/SRR622461_1.fastq.gz" "$FQ1"
    dl "https://ftp.sra.ebi.ac.uk/vol1/fastq/SRR622/SRR622461/SRR622461_2.fastq.gz" "$FQ2"

    SAMPLESHEET="$WORKDIR/samplesheet_germinal.csv"
    cat > "$SAMPLESHEET" <<EOF
patient,sample,lane,fastq_1,fastq_2,sex,status
NA12878,NA12878,1,$FQ1,$FQ2,XX,0
EOF

    OUT="${OUTDIR:-results_germline}"
    mkdir -p "$OUT"

    echo ">>> Ejecutando Sarek GERMINAL con perfil $PROFILE"
    nextflow run nf-core/sarek \
      --input "$SAMPLESHEET" \
      --genome "$GENOME" \
      --outdir "$OUT" \
      -profile "$PROFILE" \
      -c "$NF_CONFIG" \   ### NUEVO: pasamos el config
      $RESUME_FLAG
    ;;

  somatico|somatic)
    echo ">>> Modo SOMÁTICO (tumor/normal)"

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

    OUT="${OUTDIR:-results_somatic}"
    mkdir -p "$OUT"

    echo ">>> Ejecutando Sarek SOMÁTICO con perfil $PROFILE"
    nextflow run nf-core/sarek \
      --input "$SAMPLESHEET" \
      --genome "$GENOME" \
      --outdir "$OUT" \
      --somatic \
      -profile "$PROFILE" \
      -c "$NF_CONFIG" \   ### NUEVO: pasamos el config
      $RESUME_FLAG
    ;;

  *)
    echo "[ERROR] Modo no reconocido: $MODE (usa 'germinal' o 'somatico')"
    exit 1
    ;;
esac

echo ">>> Listo."
