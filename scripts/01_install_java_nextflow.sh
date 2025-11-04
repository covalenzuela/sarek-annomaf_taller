#!/usr/bin/env bash
set -euo pipefail

echo ">>> Instalando Java 17 (si es necesario) y Nextflow en $HOME/bin"

# 1) Instalar Java (para Debian/Ubuntu; ajusta si usas otra distro)
if command -v java >/dev/null 2>&1; then
  echo "[OK] Java ya está instalado:"
  java -version
else
  if command -v apt-get >/dev/null 2>&1; then
    echo "[INFO] instalando openjdk-17-jdk via apt-get..."
    sudo apt-get update -y
    sudo apt-get install -y openjdk-17-jdk || sudo apt-get install -y temurin-17-jdk
  else
    echo "[WARN] No se detectó apt-get. Instala Java 17 manualmente para tu sistema."
  fi
fi

echo
echo ">>> Versión de Java:"
java -version || echo "[WARN] java no está disponible todavía"

# 2) Instalar Nextflow usando el script oficial en ~/bin
mkdir -p "$HOME/bin"
cd "$HOME"

if command -v nextflow >/dev/null 2>&1; then
  echo "[OK] nextflow ya está en el PATH:"
  nextflow -version
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
nextflow -version || echo "[ERROR] No se pudo ejecutar nextflow. Revisa el PATH."
