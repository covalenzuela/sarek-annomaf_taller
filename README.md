# Taller: nf-core/sarek desde cero (con Jupyter + pyenv)

Este repositorio contiene el material para un taller práctico donde:

1. Creamos un **entorno de Python** con `pyenv` para:
   - ejecutar **Jupyter**,
   - instalar y usar la CLI de **nf-core**.
2. Instalamos **Java 17** y **Nextflow** a nivel de usuario.
3. Ejecutamos **nf-core/sarek** con el **perfil de prueba** (`-profile test,<motor>`).
4. Dejamos preparado el **puente hacia ANNOMAF** (pendiente de comandos finales).

---

## 0. Requisitos

- Sistema operativo:
  - Linux o macOS (Windows usando WSL2).
- Acceso a internet (descarga de contenedores/imágenes).
- Permisos para instalar paquetes a nivel de usuario (no necesariamente root, salvo Java en algunas distros).
- Idealmente:
  - `pyenv` (y opcionalmente `pyenv-virtualenv`),
  - `git`.

---

## 1. Clonar este repositorio

```bash
git clone https://github.com/covalenzuela/sarek_taller.git
cd sarek_taller
```

---

## 2. Configurar el entorno de Python con pyenv

Este repositorio asume el uso de **pyenv** para manejar versiones de Python.

### 2.1 Instalar pyenv (si no lo tienes)

Sigue las instrucciones oficiales:  
https://github.com/pyenv/pyenv#installation

Ejemplo (Linux, usando curl):

```bash
curl https://pyenv.run | bash
# Añadir a tu ~/.bashrc o equivalente:
# export PATH="$HOME/.pyenv/bin:$PATH"
# eval "$(pyenv init -)"
# eval "$(pyenv virtualenv-init -)"
source ~/.bashrc
```

### 2.2 Crear el entorno del taller

En este repo verás un archivo `.python-version` con un nombre de entorno sugerido (`sarek_taller-pyenv`).

```bash
# Instalar versión de Python (ajusta si quieres otra)
pyenv install 3.10.14

# Crear entorno virtual con pyenv-virtualenv
pyenv virtualenv 3.10.14 sarek_taller-pyenv

# Asociar ese entorno a esta carpeta
pyenv local sarek_taller-pyenv
```

### 2.3 Instalar dependencias de Python

```bash
pip install --upgrade pip
pip install -r requirements.txt
```

Esto instala:
- `jupyterlab`
- `nf-core`
- otras dependencias mínimas.

---

## 3. Instalar Java 17 y Nextflow (scripts)

Vamos a usar los scripts del directorio `scripts/`:

1. Instalar Java 17 + Nextflow:

```bash
bash scripts/01_install_java_nextflow.sh
```

2. Verificar:

```bash
nextflow -version
java -version
```

---

## 4. Ejecutar Sarek (perfil de prueba)

1. Asegúrate de tener **Docker** o **Conda** o **Apptainer**.
2. Ejecuta:

```bash
bash scripts/02_run_sarek_test.sh
```

Esto:
- fija `NXF_VER=25.10.0` (para cumplir requisitos de Sarek),
- ejecuta `nf-core/sarek` con el perfil `test,<motor>`,
- guarda resultados en `results_test_sarek/`.

---

## 5. Trabajar desde Jupyter

Dentro del entorno pyenv:

ls
jupyter lab
```

Abre el archivo `notebooks/01_sarek_from_zero.md` o crea un `.ipynb` con el contenido propuesto ahí, copiando las celdas que necesites.  
Desde Jupyter podrás:

- ejecutar comandos de shell con `%%bash`,
- hacer `!nextflow -version`, `!nf-core list`, etc.

---

## 6. Siguiente etapa: ANNOMAF

Este repositorio deja preparado:

- Carpeta para inputs de ANNOMAF,
- Scripts y secciones en el notebook para copiar VCFs de Sarek hacia ANNOMAF.

Cuando tengas definido el comando real de ANNOMAF (imagen Docker, PyPI, repo de GitHub), puedes:

- añadir un script `scripts/05_run_annomaf.sh`,
- o nuevas celdas en el notebook de Jupyter.

---

## 7. Estructura del repo

```text
.
├── README.md
├── .python-version
├── requirements.txt
├── .gitignore
├── scripts/
│   ├── 01_install_java_nextflow.sh
│   ├── 02_run_sarek_test.sh
│   ├── 03_run_sarek_with_samplesheet.sh
│   └── 04_run_sarek_germline_with_configs.sh
└── notebooks/
    └── 01_sarek_from_zero.md
```

> Este repo está pensado como punto de partida para un taller, no como entorno de producción.  
> Para usos clínicos o productivos, revisa siempre la documentación oficial y lineamientos de tu institución.
