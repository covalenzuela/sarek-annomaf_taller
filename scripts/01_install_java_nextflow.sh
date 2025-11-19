#!/usr/bin/env bash
set -euo pipefail

REQUIRED_JAVA_MAJOR=17

echo ">>> Instalando Java ${REQUIRED_JAVA_MAJOR}+ (si es necesario) y Nextflow en \$HOME/bin"

log()   { echo "[INFO] $*"; }
warn()  { echo "[WARN] $*" >&2; }
error() { echo "[ERROR] $*" >&2; exit 1; }

detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt-get"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v zypper >/dev/null 2>&1; then
    echo "zypper"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  else
    echo "unknown"
  fi
}

install_java17() {
  local pm
  pm="$(detect_pkg_manager)"

  case "$pm" in
    apt-get)
      log "Instalando Java 17 vía apt-get (openjdk-17-jdk o temurin-17-jdk)..."
      sudo apt-get update -y
      if ! sudo apt-get install -y openjdk-17-jdk; then
        warn "No se pudo instalar openjdk-17-jdk, probando temurin-17-jdk..."
        sudo apt-get install -y temurin-17-jdk || warn "No se pudo instalar temurin-17-jdk."
      fi
      ;;
    dnf)
      log "Instalando Java 17 vía dnf..."
      sudo dnf install -y java-17-openjdk-devel || warn "Fallo instalación con dnf."
      ;;
    yum)
      log "Instalando Java 17 vía yum..."
      sudo yum install -y java-17-openjdk-devel || warn "Fallo instalación con yum."
      ;;
    zypper)
      log "Instalando Java 17 vía zypper..."
      sudo zypper install -y java-17-openjdk-devel || warn "Fallo instalación con zypper."
      ;;
    pacman)
      log "Instalando Java 17 vía pacman..."
      sudo pacman -Sy --noconfirm jdk17-openjdk || warn "Fallo instalación con pacman."
      ;;
    *)
      warn "No se detectó un gestor de paquetes soportado. Instala Java 17 manualmente."
      ;;
  esac
}

get_java_major() {
  # Usa el java actual en PATH
  if ! command -v java >/dev/null 2>&1; then
    echo ""
    return
  fi

  # Capturar la primera línea de `java -version`
  local ver_line ver_str major
  ver_line="$(java -version 2>&1 | head -n1 || true)"

  # Extraer lo que está entre comillas: "17.0.10" o "1.8.0_45"
  ver_str="$(printf '%s\n' "$ver_line" | sed -E 's/.*version "([^"]+)".*/\1/' || true)"

  if [ -z "$ver_str" ]; then
    echo ""
    return
  fi

  major="${ver_str%%.*}"  # antes del primer punto

  # Manejar formato antiguo tipo 1.8.0_xx → major = 8
  if [ "$major" = "1" ]; then
    # segundo componente: 8 en 1.8.0_45
    local minor
    minor="$(printf '%s\n' "$ver_str" | cut -d. -f2)"
    major="$minor"
  fi

  echo "$major"
}

ensure_java() {
  local major

  if ! command -v java >/dev/null 2>&1; then
    warn "Java no está instalado. Intentando instalar Java ${REQUIRED_JAVA_MAJOR}..."
    install_java17
  else
    log "Java ya está instalado. Versión detectada:"
    java -version 2>&1 || true
  fi

  major="$(get_java_major || true)"

  if [ -z "$major" ]; then
    warn "No se pudo determinar la versión de Java. Intenta configurar Java 17 manualmente."
    return
  fi

  log "Versión mayor detectada de Java: $major"

  if [ "$major" -lt "$REQUIRED_JAVA_MAJOR" ]; then
    warn "La versión actual de Java ($major) es menor que la requerida ($REQUIRED_JAVA_MAJOR)."
    warn "Intentando instalar/actualizar a Java ${REQUIRED_JAVA_MAJOR}..."
    install_java17
    major="$(get_java_major || true)"
    if [ -z "$major" ] || [ "$major" -lt "$REQUIRED_JAVA_MAJOR" ]; then
      error "No se pudo obtener una versión de Java >= ${REQUIRED_JAVA_MAJOR}. Ajusta Java manualmente y vuelve a ejecutar el script."
    fi
  fi

  log "Java cumple el requisito (>= ${REQUIRED_JAVA_MAJOR})."
}

echo ">>> Comprobando e instalando Java..."
ensure_java

echo
echo ">>> Versión de Java tras la comprobación:"
java -version 2>&1 || warn "java no está disponible a pesar del intento de instalación."

# 2) Instalar Nextflow usando el script oficial en ~/bin
mkdir -p "$HOME/bin"
cd "$HOME"

if command -v nextflow >/dev/null 2>&1; then
  echo "[OK] nextflow ya está en el PATH:"
  nextflow -version || warn "No se pudo obtener la versión de nextflow."
else
  echo "[INFO] descargando nextflow con get.nextflow.io..."
  curl -s https://get.nextflow.io | bash
  chmod +x nextflow
  mv nextflow "$HOME/bin/"
fi

echo
echo ">>> Asegúrate de tener en tu ~/.bashrc:"
echo 'export PATH="$HOME/bin:$PATH"'
echo
echo ">>> Probando nextflow:"
export PATH="$HOME/bin:$PATH"
nextflow -version || error "No se pudo ejecutar nextflow. Revisa el PATH o la instalación de Java."
echo ">>> Instalación/comprobación de Java y Nextflow completada."