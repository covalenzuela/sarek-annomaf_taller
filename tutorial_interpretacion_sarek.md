# Tutorial básico de interpretación de variantes  
## A partir del VCF de salida de Sarek

Este tutorial te enseña, de manera muy simple, a **leer e interpretar variantes** presentes en un archivo **VCF** generado por el pipeline **nf-core/Sarek**.

---

## 1. ¿Qué es un VCF?

El VCF contiene:

- La **posición** de cada variante (cromosoma y coordenada).
- El **cambio** en el ADN (REF vs ALT).
- Información de **cobertura y calidad**.
- Anotaciones generadas por Sarek (p. ej., **SnpEff** / **VEP**) que predicen:
  - El **gen** afectado.
  - El **tipo de variante** (missense, nonsense, frameshift, etc.).
  - El **impacto** (LOW, MODERATE, HIGH).
  - Cambios en proteína (ej. `p.Val600Glu`).

---

## 2. Cómo abrir el VCF

Puedes inspeccionarlo con:

```bash
zcat results.vcf.gz | less -S
```

O mostrar solo las primeras filas:

```bash
zcat results.vcf.gz | head
```

---

## 3. Identificar la información clave de cada variante

Una fila del VCF suele verse así:

```
chr7    140453136   .   A   T   PASS   ...   ANN=T|missense_variant|MODERATE|BRAF|...
```

Lo importante es:

- **CHROM** y **POS** → dónde está la variante.  
- **REF / ALT** → cuál es el cambio.  
- **FILTER** → si aparece “PASS”, pasó los filtros de calidad.  
- **INFO / ANN** → contiene la anotación funcional:
  - Gen → `BRAF`
  - Tipo de variante → `missense_variant`
  - Impacto → `MODERATE`
  - Cambio proteico → `p.Val600Glu`

---

## 4. Filtrar las variantes más importantes

Las variantes más relevantes suelen ser las que:

1. Tienen **FILTER = PASS**  
2. Tienen impacto **MODERATE** o **HIGH**  
3. Están en genes asociados a funciones biológicas relevantes

Para filtrar rápidamente:

```bash
zcat results.vcf.gz | grep PASS | grep -E "MODERATE|HIGH"
```

---

## 5. Interpretar el impacto funcional

SnpEff/VEP clasifican variantes según su efecto:

| Impacto | Significado | Ejemplo |
|---------|-------------|---------|
| **HIGH** | Probablemente altera la función de la proteína | `stop_gained`, `frameshift` |
| **MODERATE** | Podría alterar la proteína | `missense_variant` |
| LOW | Probablemente no afecta | `synonymous_variant` |
| MODIFIER | Difícil de interpretar / intergénica | No afecta codones |

> Para un análisis rápido, enfócate en **HIGH** y **MODERATE**.

---

## 6. Identificar el cambio proteico

En el campo `ANN`, busca información como:

```
p.Val600Glu
```

Esto indica:

- Cambio de aminoácido Valina → Glutámico  
- Posición 600 de la proteína  

---

## 7. Buscar la variante en bases externas

### 7.1. gnomAD  
👉 https://gnomad.broadinstitute.org  

### 7.2. ClinVar  
👉 https://www.ncbi.nlm.nih.gov/clinvar/

---

## 8. Ejemplo sencillo de interpretación

Entrada VCF:

```
chr21   45989090    .   C   T   PASS   ... ANN=T|stop_gained|HIGH|COL6A1|...|p.Arg271*|
```

Interpretación:

- Gen: **COL6A1**  
- Cambio: C→T  
- Tipo: `stop_gained`  
- Impacto: HIGH  
- Proteína: `p.Arg271*`  
- Frecuencia gnomAD: muy baja  
- ClinVar: patogénica  

**Conclusión:** Variante fuerte candidata.

---

## 9. Flujo recomendado

1. Filtrar PASS  
2. Filtrar HIGH / MODERATE  
3. Ver gen  
4. Ver cambio proteico  
5. Consultar gnomAD  
6. Consultar ClinVar  
7. Evaluar relevancia

---

## 10. Actividad para estudiantes

Seleccionar 3 variantes y responder:

- Gen  
- Tipo  
- Impacto  
- Cambio proteico  
- Frecuencia gnomAD  
- Clasificación ClinVar  
- Conclusión

---

## 11. Resumen final

El VCF de Sarek permite interpretar variantes revisando:

- Tipo, impacto  
- Gen  
- Frecuencia poblacional  
- Evidencia clínica  

Permite reducir cientos de variantes a pocas candidatas.

---
