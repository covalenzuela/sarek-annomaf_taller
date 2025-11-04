# De cero a nf-core/sarek con Jupyter + pyenv

> Este archivo se usa como guía dentro de Jupyter.  
> Cada bloque `bash` se puede convertir en celda `%%bash` de código.

---

## 1) Activar entorno pyenv del taller

```bash
cd /ruta/al/repo/sarek-workshop
pyenv local sarek-workshop-pyenv
which python
python --version
```

---

## 2) Probar instalación de Python, nf-core y Jupyter

```bash
python -m pip show nf-core
jupyter --version
nf-core --version
```

---

## 3) Verificar Java y Nextflow

```bash
java -version
nextflow -version
```

Si algo falla, ejecutar el script:

```bash
bash scripts/01_install_java_nextflow.sh
```

y volver a probar.

---

## 4) Primer contacto con nf-core

```bash
nf-core list | head
```

---

## 5) Ejecutar Sarek (perfil test) desde Jupyter

> En una celda de código en Jupyter, usa `%%bash`:

```bash
%%bash
cd "$HOME/sarek_taller"
export NXF_VER=25.10.0
nextflow run nf-core/sarek -profile test,docker --outdir results_test_sarek
```

Cambia `docker` por `podman`, `apptainer` o `conda` según tu entorno.

---

## 6) Explorar resultados

```bash
%%bash
cd "$HOME/sarek_taller"
find results_test_sarek -maxdepth 3 -type f | sed -n '1,80p'
```

---

## 7) Ejemplo de samplesheet propio

```python
import pandas as pd

rows = [
    {"sample":"S1", "fastq_1":"/ruta/S1_R1.fastq.gz", "fastq_2":"/ruta/S1_R2.fastq.gz", "sex":"XX"},
    {"sample":"S2", "fastq_1":"/ruta/S2_R1.fastq.gz", "fastq_2":"/ruta/S2_R2.fastq.gz", "sex":"XY"},
]
df = pd.DataFrame(rows)
df.to_csv("samplesheet.csv", index=False)
df
```

---

## 8) Sarek con samplesheet

```bash
%%bash
cd "$HOME/sarek_taller"
export NXF_VER=25.10.0
nextflow run nf-core/sarek   --input samplesheet.csv   --genome GATK.GRCh38   --outdir results_germline   -profile docker
```

---

## 9) Puente a ANNOMAF (borrador)

```bash
%%bash
cd "$HOME/sarek_taller"
mkdir -p annomaf_inputs annomaf_outputs
# Copiar un VCF de ejemplo
find results_test_sarek -type f -name "*.vcf.gz" | head -n1 | xargs -I{} cp -n "{}" annomaf_inputs/ || true
ls -l annomaf_inputs
```

Luego, aquí iría el comando real de ANNOMAF:

```bash
%%bash
cd "$HOME/sarek_taller"
# Ejemplo ficticio:
# annomaf run --input annomaf_inputs/*.vcf.gz --out annomaf_outputs/
echo "TODO: agrega aquí el comando real de ANNOMAF."
```
