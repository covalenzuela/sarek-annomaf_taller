#!/usr/bin/env bash
set -euo pipefail

# 01_install_java_nextflow.sh
# Instala Java 17 y Nextflow SOLO dentro de este repositorio
# y crea un script de activación: ./activate_env.sh
# Además muestra un resumen de:
# - versiones del sistema (si existen)
# - versiones locales instaladas

BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
SOFT_DIR="$BASE_DIR/software"
JAVA_DIR="$SOFT_DIR/java-17"
NXF_BIN="$SOFT_DIR/nextflow"

JDK_VERSION_HUMANO="OpenJDK 17 (BellSoft)"
JDK_URL="https://download.bell-sw.com/java/17.0.13+12/bellsoft-jdk17.0.13+12-linux-amd64.tar.gz"
TARGET_NXF_VER="25.10.0"

mkdir -p "$SOFT_DIR"

echo "======================================================="
echo " 01) CHEQUEO DE ENTORNO DEL SISTEMA (ANTES)"
echo "======================================================="

if command -v java >/dev/null 2>&1; then
  echo "Sistema: java encontrado en: $(command -v java)"
  java -version || true
else
  echo "Sistema: java NO encontrado en PATH"
fi
echo

if command -v nextflow >/dev/null 2>&1; then
  echo "Sistema: nextflow encontrado en: $(command -v nextflow)"
  nextflow -version || true
else
  echo "Sistema: nextflow NO encontrado en PATH"
fi

echo
echo "Se instalará localmente en este repo:"
echo "  - Java : $JDK_VERSION_HUMANO"
echo "  - NXF_VER objetivo: $TARGET_NXF_VER"
echo
echo "Carpeta del taller:          $BASE_DIR"
echo "Carpeta para software local: $SOFT_DIR"
echo "======================================================="
echo

########################################
# 1) Instalar Java 17 local
########################################

if [[ ! -x "$JAVA_DIR/bin/java" ]]; then
  echo ">>> Descargando $JDK_VERSION_HUMANO (local, sin tocar el sistema)..."
  echo ">>> (Usando curl --insecure por certificados antiguos en CentOS 7)"

  JDK_TAR="$SOFT_DIR/openjdk17.tar.gz"
  # PARCHE: --insecure para evitar error de certificado en CentOS 7
  curl -L --insecure "$JDK_URL" -o "$JDK_TAR"

  echo ">>> Descomprimiendo Java 17..."
  tar -xzf "$JDK_TAR" -C "$SOFT_DIR"

  # Carpeta que se creó dentro de software/
  JDK_EXTRACTED_DIR="$(tar -tf "$JDK_TAR" | head -1 | cut -d/ -f1)"

  mv "$SOFT_DIR/$JDK_EXTRACTED_DIR" "$JAVA_DIR"
  rm -f "$JDK_TAR"
else
  echo ">>> Java 17 ya está instalado en $JAVA_DIR"
fi

########################################
# 2) Instalar Nextflow local
########################################

if [[ ! -x "$NXF_BIN" ]]; then
  echo ">>> Descargando Nextflow (local, sin usar ~/bin)..."
  echo ">>> (Usando curl --insecure por certificados antiguos en CentOS 7)"
  cd "$SOFT_DIR"
  # PARCHE: --insecure también aquí por el mismo problema de certificados
  curl -s --insecure https://get.nextflow.io | bash
  mv nextflow "$NXF_BIN"
  chmod +x "$NXF_BIN"
else
  echo ">>> Nextflow ya está instalado en $NXF_BIN"
fi

########################################
# 3) Crear script de activación de entorno
########################################

cat > "$BASE_DIR/activate_env.sh" <<EOF
# Activar entorno local del taller Sarek
export JAVA_HOME="$JAVA_DIR"
export PATH="\$JAVA_HOME/bin:$SOFT_DIR:\$PATH"

# Nextflow y cache de Sarek locales a este repo
export NXF_HOME="$BASE_DIR/.nextflow"
export NXF_DEFAULT_WORK_DIR="$BASE_DIR/work"
export NXF_VER="${TARGET_NXF_VER}"

alias nextflow="$NXF_BIN"
EOF

chmod +x "$BASE_DIR/activate_env.sh"

########################################
# 4) Crear carpetas de trabajo
########################################

mkdir -p "$BASE_DIR/work"
mkdir -p "$BASE_DIR/output"
mkdir -p "$BASE_DIR/samplesheets"

########################################
# 5) Resumen de entorno LOCAL (después)
########################################

echo
echo "======================================================="
echo " 02) CHEQUEO DE ENTORNO LOCAL (DESPUÉS)"
echo "======================================================="
# shellcheck source=/dev/null
source "$BASE_DIR/activate_env.sh"

echo "JAVA_HOME = $JAVA_HOME"
echo "NXF_HOME  = ${NXF_HOME:-no_definido}"
echo "NXF_VER   = ${NXF_VER:-no_definido}"
echo

echo "java -version (local):"
java -version || true
echo

echo "nextflow -version (local):"
nextflow -version || true

echo
echo "======================================================="
echo " Entorno local listo para ESTE repositorio."
echo
echo " En cada terminal, el alumno/profe debe hacer:"
echo "   cd \"$BASE_DIR\""
echo "   source activate_env.sh"
echo
echo " Luego puede probar:"
echo "   java -version"
echo "   nextflow -version"
echo
echo " Y ejecutar:"
echo "   bash scripts/02_run_sarek_test.sh"
echo "   bash scripts/03_run_sarek_with_samplesheet.sh ..."
echo "======================================================="
