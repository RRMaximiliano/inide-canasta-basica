---
output: github_document
---

<!-- README.md is generated from README.Rmd. Please edit that file -->



# Canasta Básica de Nicaragua

<!-- badges: start -->
[![Data Update](https://github.com/RRMaximiliano/inide-canasta-basica/actions/workflows/update-data.yml/badge.svg)](https://github.com/RRMaximiliano/inide-canasta-basica/actions/workflows/update-data.yml)
<!-- badges: end -->

## Qué hace este proyecto

Recolecta y visualiza automáticamente los datos de precios de la canasta básica de Nicaragua desde el sitio web oficial del INIDE. Además de los precios nominales, calcula **precios reales** (ajustados por inflación) y clasifica cada bien en su **categoría oficial**.

**Aplicación en vivo**: https://rrmaximiliano.shinyapps.io/inide-canasta-basica/

**Datos actuales** (actualizado: 2026-06-22):
- **Cobertura**: Sep 2007 - May 2026
- **Registros**: 11,925 observaciones
- **Bienes**: 53 artículos únicos (limpios y estandarizados)
- **Categorías**: 3 grupos oficiales (Alimentos, Usos del Hogar, Vestuario)
- **Costo actual**: C$ 21,373 (+0.6% vs mes anterior)

**Actualización automática**: Este repositorio se actualiza automáticamente cada semana (los lunes) mediante GitHub Actions, descargando los datos más recientes del sitio web oficial del INIDE. Cuando hay un mes nuevo, se recompila el dataset, se regeneran las figuras y se redespliega la aplicación Shiny.

## Vista de los datos


``` r
canasta_basica
#> # A tibble: 11,925 × 17
#>    yymm       year month url      row   good  medida cantidad precio total    id
#>    <glue>    <dbl> <fct> <chr>    <chr> <chr> <chr>     <dbl>  <dbl> <dbl> <dbl>
#>  1 CB2007Dic  2007 Dic   https:/… 1     Arroz libra        38   7.12  270.     4
#>  2 CB2007Dic  2007 Dic   https:/… 2     Frij… libra        34  14.4   491.     4
#>  3 CB2007Dic  2007 Dic   https:/… 3     Azúc… libra        30   4.97  149.     4
#>  4 CB2007Dic  2007 Dic   https:/… 4     Acei… litro         7  27.4   192.     4
#>  5 CB2007Dic  2007 Dic   https:/… 5     Post… libra         8  33.5   268.     4
#>  6 CB2007Dic  2007 Dic   https:/… 6     Post… libra         5  31.6   158.     4
#>  7 CB2007Dic  2007 Dic   https:/… 7     Carn… libra         8  18.3   147.     4
#>  8 CB2007Dic  2007 Dic   https:/… 8     Chul… libra         9  35.4   319.     4
#>  9 CB2007Dic  2007 Dic   https:/… 9     Leche litro        30  11.9   356.     4
#> 10 CB2007Dic  2007 Dic   https:/… 10    Huev… docena        7  26.1   183.     4
#> # ℹ 11,915 more rows
#> # ℹ 6 more variables: ym <date>, categoria <fct>, ipc <dbl>,
#> #   ipc_estimado <lgl>, precio_real <dbl>, total_real <dbl>
```

### Tendencia reciente del costo total



|  Año|Mes |Costo Total (nominal) |Costo Total (real) |
|----:|:---|:---------------------|:------------------|
| 2026|May |C$ 21,373             |C$ 21,000          |
| 2026|Abr |C$ 21,246             |C$ 20,875          |
| 2026|Mar |C$ 21,120             |C$ 20,752          |
| 2026|Feb |C$ 21,164             |C$ 20,795          |
| 2026|Ene |C$ 21,250             |C$ 20,879          |
| 2025|Dic |C$ 20,822             |C$ 20,458          |
| 2025|Nov |C$ 20,768             |C$ 20,406          |
| 2025|Oct |C$ 20,559             |C$ 20,200          |
| 2025|Sep |C$ 20,594             |C$ 20,235          |
| 2025|Ago |C$ 20,529             |C$ 20,171          |
| 2025|Jul |C$ 20,550             |C$ 20,191          |
| 2025|Jun |C$ 20,487             |C$ 20,130          |



*Precios reales en córdobas constantes de 2024.*

Cada base de datos contiene las siguientes variables:

* `yymm`: Año - Mes de la canasta básica.
* `year`: Año.
* `month`: Mes.
* `url`: URL de descarga de la página oficial del INIDE.
* `row`: Número oficial del bien (1-53).
* `good`: Nombre del bien (limpio y estandarizado).
* `medida`: Medida oficial de consumo.
* `cantidad`: Cantidad de consumo (en medida).
* `precio`: Precio nominal por medida.
* `total`: Gasto nominal del bien (cantidad × precio).
* `id`: Identificador interno del lote de descarga (artefacto del proceso de recolección; no identifica al bien).
* `ym`: Fecha del primer día del mes correspondiente (a partir de `year` y `month`).
* `categoria`: Grupo oficial del bien (Alimentos, Usos del Hogar, Vestuario).
* `ipc`: Índice de precios al consumidor de Nicaragua (FMI / IFS, base 2010 = 100) del mes.
* `ipc_estimado`: `TRUE` si el IPC del mes fue extrapolado (meses recientes aún sin dato oficial).
* `precio_real`: Precio real, en córdobas constantes de 2024.
* `total_real`: Gasto real, en córdobas constantes de 2024.

**Limpieza de datos**: Los datos han sido procesados para estandarizar los nombres de los bienes y corregir inconsistencias. Por ejemplo, variaciones como "Pasta dental" y "Pastas dental" se han unificado, y se han diferenciado artículos similares como "Calcetines (Hombre)" y "Calcetines (Niños y Niñas)". La limpieza se aplica automáticamente durante el proceso de recolección de datos.

## Categorías

La canasta básica de 53 productos se organiza en los tres grupos oficiales del INIDE:



|Categoría      |Costo del grupo |
|:--------------|:---------------|
|Alimentos      |C$ 15,328       |
|Usos del Hogar |C$  3,645       |
|Vestuario      |C$  2,400       |



*Desglose del último mes disponible (May 2026).*

## Precios reales (ajustados por inflación)

Los precios nominales no son comparables a lo largo de 18 años: gran parte del aumento refleja inflación general, no encarecimiento real. Por eso el dataset incluye **precios reales** en córdobas constantes de 2024, deflactados con el Índice de Precios al Consumidor (IPC) mensual de Nicaragua publicado por el FMI (International Financial Statistics, base 2010 = 100), obtenido vía la API de DBnomics. Los meses más recientes que aún no tienen IPC oficial usan el último valor disponible (marcados con `ipc_estimado = TRUE`).

![plot of chunk unnamed-chunk-5](figures/canasta_nominal_real.png)

## Ejemplos

![plot of chunk unnamed-chunk-6](figures/canasta_basica.png)![plot of chunk unnamed-chunk-6](figures/canasta_categoria.png)![plot of chunk unnamed-chunk-6](figures/arroz.png)![plot of chunk unnamed-chunk-6](figures/queso_seco.png)

## Cómo usar estos datos

Los datos están disponibles directamente desde GitHub en formato CSV, RDS y Stata:

```r
# R
library(readr)
canasta <- read_csv("https://raw.githubusercontent.com/RRMaximiliano/inide-canasta-basica/main/data/CB_FULL.csv")

# R (formato nativo, conserva tipos)
canasta <- readRDS(url("https://raw.githubusercontent.com/RRMaximiliano/inide-canasta-basica/main/data/CB_FULL.rds"))
```

```python
# Python
import pandas as pd
canasta = pd.read_csv("https://raw.githubusercontent.com/RRMaximiliano/inide-canasta-basica/main/data/CB_FULL.csv")
```

```stata
* Stata
import delimited "https://raw.githubusercontent.com/RRMaximiliano/inide-canasta-basica/main/data/CB_FULL.csv", clear
* o descargue el .dta:
* copy "https://raw.githubusercontent.com/RRMaximiliano/inide-canasta-basica/main/data/CB_FULL.dta" CB_FULL.dta
* use CB_FULL.dta, clear
```

**Cita sugerida**: Rodríguez Ramírez, R. M. (2026). *Canasta Básica de Nicaragua* [conjunto de datos]. https://github.com/RRMaximiliano/inide-canasta-basica. Fuente primaria: INIDE; IPC: FMI / IFS.

## Estructura del Proyecto

```
├── 01_files.R              # Configuración de URLs para datos históricos (legado)
├── 02_scrape.R             # Script original de recolección (histórico)
├── 02_scrape_auto.R        # Recolector automatizado (actual)
├── 03_plots.R              # Generación de figuras
├── app.R                   # Aplicación web Shiny
├── README.Rmd              # Fuente de documentación
├── R/                      # Lógica compartida (single source of truth)
│   ├── clean_canasta_data.R  # Limpieza y estandarización
│   ├── categories.R          # Mapeo de bienes a categorías oficiales
│   ├── ipc.R                 # IPC y cálculo de precios reales
│   └── compile_canasta.R     # Pipeline completo
├── scripts/                # Utilidades de mantenimiento y validación
│   └── validate_data.R       # Validación automática (corre en CI)
├── tests/                  # Pruebas de la lógica de compilación
├── data/
│   ├── CB_FULL.rds         # Dataset principal (limpio)
│   ├── CB_FULL.csv         # Versión CSV
│   ├── CB_FULL.dta         # Versión Stata
│   ├── ipc_nicaragua.csv   # Serie de IPC mensual (caché)
│   └── monthly/            # Archivos mensuales individuales
└── .github/workflows/      # Automatización GitHub Actions
```

## Cómo funciona

1. **Automatización semanal**: GitHub Actions se ejecuta cada lunes
2. **Detección inteligente**: Solo descarga datos nuevos del sitio web del INIDE
3. **Compilación**: Estandariza nombres, asigna categorías y calcula precios reales
4. **Validación**: `scripts/validate_data.R` verifica la integridad antes de publicar
5. **Actualización de app**: La aplicación Shiny se redespliega con los datos más recientes

## Características principales

- **Completamente automatizado**: No requiere intervención manual
- **Calidad de datos**: Nomenclatura consistente y validación automática en CI
- **Precios reales**: Ajustados por inflación (IPC de Nicaragua)
- **Categorías**: Cada bien clasificado en su grupo oficial
- **Siempre actualizado**: Se actualiza semanalmente con los datos más recientes
- **Interactivo**: Aplicación web para exploración de datos
- **Múltiples formatos**: Archivos RDS, CSV y Stata disponibles
- **Código abierto**: Todo el código disponible en GitHub

## Contacto y contribuciones

Para comentarios, sugerencias o contribuciones:
- **Email**: rodriguezramirez@worldbank.org
- **Issues**: <https://github.com/RRMaximiliano/inide-canasta-basica/issues>
- **Fuente de datos**: INIDE Nicaragua

---

*Mantenido por @RRMaximiliano | Última actualización: 2026-06-22*
