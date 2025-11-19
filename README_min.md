# README (mínimo) — Taller Sarek

Guía ultra‑breve con **solo comandos** en el orden recomendado.

---

## 0) Ubicación del repo
Colócate en la carpeta del repo/clase (donde está `scripts/`):
```bash
cd ~/korostica/tutoriales/sarek-annomaf_taller
```

> Si usas `pyenv`, basta con entrar a esta carpeta para activar el entorno.

---

## 1) Test rápido del pipeline (perfil `test`)
**Recomendado:** usa el script que **sobrescribe** report/timeline/trace y guarda todo en `~/sarek_taller/results_test_sarek/`.

```bash
bash scripts/02_run_sarek_test.sh
```

> Repetir la ejecución:
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
# o:
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
