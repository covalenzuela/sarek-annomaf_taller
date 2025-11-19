# README (mínimo) — Taller Sarek

Guía ultra-breve con **solo comandos** en el orden recomendado.

---

## 0) Ubicación del repo + entorno (pyenv)

Colócate en la carpeta del repo/clase (donde está `scripts/`):
```bash
cd ~/korostica/tutoriales/sarek-annomaf_taller
```

Activa / comprueba el entorno Python (si usas `pyenv`):
```bash
# Si este repo define el entorno con .python-version:
pyenv version            # debería mostrar: sarek_taller-pyenv
python -V                # por ejemplo: Python 3.10.x
which python             # debería estar en ~/.pyenv/shims/python

# Si no se activa solo, fuerzalo:
pyenv activate sarek_taller-pyenv
```

> Si tu prompt **no** muestra el nombre del entorno, aun así verifica con `pyenv version` y `which python`.

---

## 1) Test rápido del pipeline (perfil `test`)

**Recomendado:** usa el script que **sobrescribe** report/timeline/trace y guarda todo en `~/sarek_taller/results_test_sarek/`.

```bash
bash scripts/02_run_sarek_test.sh
```

Repetir la ejecución:
```bash
RESUME=1 bash scripts/02_run_sarek_test.sh
```

---

## 2) Ejecutar con datos de ejemplo (descarga automática)

### 2.1 Germinal (NA12878, GIAB)
```bash
bash scripts/03_run_sarek_with_samplesheet.sh germinal
```

Reanudar si hubo corte:
```bash
RESUME=1 bash scripts/03_run_sarek_with_samplesheet.sh germinal
```

Con anotación:
```bash
ANNOTATORS=snpeff RESUME=1 bash scripts/03_run_sarek_with_samplesheet.sh germinal
# o
ANNOTATORS=vep,snpeff RESUME=1 bash scripts/03_run_sarek_with_samplesheet.sh germinal
```

### 2.2 Somático (par T/N PRJNA240067)
```bash
bash scripts/03_run_sarek_with_samplesheet.sh somatico
```

Reanudar:
```bash
RESUME=1 bash scripts/03_run_sarek_with_samplesheet.sh somatico
```

Resultados (por defecto):
```bash
# Germinal
ls -1 ~/sarek_taller/results_germline/multiqc/multiqc_report.html

# Somático
ls -1 ~/sarek_taller/results_somatic/multiqc/multiqc_report.html
```

---

## 3) (Opcional) Verificar runtimes disponibles

```bash
command -v docker      && docker --version
command -v podman      && podman --version
command -v apptainer   && apptainer --version
command -v singularity && singularity --version
command -v conda       && conda --version
```

> Los scripts detectan automáticamente: **docker > podman > apptainer > singularity > conda**.  
> Para *singularity/apptainer*, el caché se define automáticamente en `~/.singularity`.

---

## 4) (Opcional) Limpiar / reanudar

Reanudar la última ejecución (si falla algo):
```bash
RESUME=1 bash scripts/03_run_sarek_with_samplesheet.sh germinal
```

Borrar resultados de **prueba**:
```bash
rm -rf ~/sarek_taller/results_test_sarek
```

> No borres `~/sarek_taller/work/` si planeas usar `-resume`.

---

## 5) Param file generado por el script 03

El script **03** crea un único archivo de parámetros en:
```
~/sarek_taller/params.yaml
```

Ejemplo típico (germinal por defecto):
```yaml
input: "/home/USUARIO/sarek_taller/samplesheet_germinal.csv"
genome: "GATK.GRCh38"
aligner: "bwa-mem2"
tools: "haplotypecaller"   # <- en minúsculas y separado por comas si hay varias
snpeff: false              # se pone true si ANNOTATORS incluye snpeff
vep: false                 # se pone true si ANNOTATORS incluye vep
use_annotation_cache_keys: true
# (si ANNOTATORS activa snpeff/vep, el script agrega campos como):
# snpeff_genome: GRCh38
# snpeff_db: 105
# vep_cache_version: 114
# vep_species: homo_sapiens
```

- **`tools`** debe ir **en minúsculas** (ej: `haplotypecaller`, `mutect2,strelka`).  
- Puedes **sobrescribir** por variable de entorno al ejecutar:
  ```bash
  TOOLS="haplotypecaller,deepvariant" ALIGNER=bwa-mem2 RESUME=1 \
  bash scripts/03_run_sarek_with_samplesheet.sh germinal
  ```

---

## 6) Comando crudo que ejecuta el script 03

Lo que lanza el script (plantilla):

**Germinal**
```bash
nextflow run nf-core/sarek \
  -params-file "$HOME/sarek_taller/params.yaml" \
  --outdir "$HOME/sarek_taller/results_germline" \
  -work-dir "$HOME/sarek_taller/work" \
  -profile RUNTIME \
  -with-report   "$HOME/sarek_taller/germinal_pipeline_info/execution_report_YYYY-MM-DD_HH-MM-SS.html" \
  -with-timeline "$HOME/sarek_taller/germinal_pipeline_info/timeline_YYYY-MM-DD_HH-MM-SS.html" \
  -with-trace    "$HOME/sarek_taller/germinal_pipeline_info/trace_YYYY-MM-DD_HH-MM-SS.txt" \
  [-resume]
```

**Somático**
```bash
nextflow run nf-core/sarek \
  -params-file "$HOME/sarek_taller/params.yaml" \
  --outdir "$HOME/sarek_taller/results_somatic" \
  --somatic \
  -work-dir "$HOME/sarek_taller/work" \
  -profile RUNTIME \
  -with-report   "$HOME/sarek_taller/somatic_pipeline_info/execution_report_YYYY-MM-DD_HH-MM-SS.html" \
  -with-timeline "$HOME/sarek_taller/somatic_pipeline_info/timeline_YYYY-MM-DD_HH-MM-SS.html" \
  -with-trace    "$HOME/sarek_taller/somatic_pipeline_info/trace_YYYY-MM-DD_HH-MM-SS.txt" \
  [-resume]
```

Donde **`RUNTIME`** es el que detectan los scripts (`docker`, `podman`, `apptainer`, `singularity` o `conda`).  
Los paths `input:` y `outdir` se fijan automáticamente según el **modo** (germinal/somático).
