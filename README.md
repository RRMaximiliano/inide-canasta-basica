---
output: github_document
---

<!-- README.md is generated from README.Rmd. Please edit that file -->



# Canasta Básica de Nicaragua

<!-- badges: start -->
[![Data Update](https://github.com/RRMaximiliano/inide-canasta-basica/actions/workflows/update-data.yml/badge.svg)](https://github.com/RRMaximiliano/inide-canasta-basica/actions/workflows/update-data.yml)
<!-- badges: end -->

## 🎯 Qué hace este proyecto

Recolecta y visualiza automáticamente los datos de precios de la canasta básica de Nicaragua desde el sitio web oficial del INIDE.

**🌐 Aplicación en vivo**: https://rrmaximiliano.shinyapps.io/inide-canasta-basica/

**📊 Datos actuales** (actualizado: 2026-01-28):
- **Cobertura**: Dic 2007 - Dic 2025
- **Registros**: 11,660 observaciones
- **Bienes**: 53 artículos únicos (limpios y estandarizados)
- **Costo actual**: C$ 20,822 (+0.3% vs mes anterior)

**🔄 Actualización automática**: Este repositorio se actualiza automáticamente cada mes el día 15 mediante GitHub Actions, descargando los datos más recientes del sitio web oficial del INIDE. 

## 📈 Vista de los datos


``` r
canasta_basica
#> # A tibble: 11,660 × 12
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
#> # ℹ 11,650 more rows
#> # ℹ 1 more variable: ym <date>
```

### Tendencia reciente del costo total



|  Año|Mes |Costo Total |
|----:|:---|:-----------|
| 2025|Dic |C$ 20,822   |
| 2025|Nov |C$ 20,768   |
| 2025|Oct |C$ 20,559   |
| 2025|Sep |C$ 20,594   |
| 2025|Ago |C$ 20,529   |
| 2025|Jul |C$ 20,550   |
| 2025|Jun |C$ 20,487   |
| 2025|May |C$ 20,457   |
| 2025|Abr |C$ 20,303   |
| 2025|Mar |C$ 20,352   |
| 2025|Feb |C$ 20,601   |
| 2025|Ene |C$ 20,394   |



Cada base de datos contiene las siguientes variables:

* `yymm`: Año - Mes de la canasta básica.
* `year`: Año.
* `month`: Mes.
* `url`: URL de descarga de la página oficial del INIDE.
* `row`: ID del bien. En total se encuentran 53 bienes.
* `good`: Nombre del bien (limpio y estandarizado).
* `medida`: Medida oficial de consumo.
* `cantidad`: Cantidad de consumo (en medida).
* `precio`: Precio por medida.
* `total`: Total de consumo.

**Limpieza de datos**: Los datos han sido procesados para estandarizar los nombres de los bienes y corregir inconsistencias. Por ejemplo, variaciones como "Pasta dental" y "Pastas dental" se han unificado, y se han diferenciado artículos similares como "Calcetines (Hombre)" y "Calcetines (Niños y Niñas)". La limpieza se aplica automáticamente durante el proceso de recolección de datos.

## Ejemplos

![plot of chunk unnamed-chunk-4](figures/canasta_basica.png)![plot of chunk unnamed-chunk-4](figures/arroz.png)![plot of chunk unnamed-chunk-4](figures/queso_seco.png)

## 📁 Estructura del Proyecto

```
├── 01_files.R              # Configuración de URLs para datos históricos
├── 02_scrape.R              # Script original de recolección (histórico)
├── 02_scrape_auto.R         # Recolector automatizado (actual/futuro)
├── app.R                    # Aplicación web Shiny
├── README.Rmd               # Fuente de documentación
├── data/
│   ├── CB_FULL.rds          # Dataset principal (limpio)
│   ├── CB_FULL.csv          # Versión CSV
│   └── monthly/             # Archivos mensuales individuales
└── .github/workflows/       # Automatización GitHub Actions
```

## 🔄 Cómo funciona

1. **Automatización mensual**: GitHub Actions se ejecuta el día 15 de cada mes
2. **Detección inteligente**: Solo descarga datos nuevos del sitio web del INIDE
3. **Limpieza de datos**: Estandariza automáticamente nombres de bienes y corrige inconsistencias
4. **Actualización de app**: La aplicación Shiny muestra los datos más recientes automáticamente

## 🚀 Características principales

- ✅ **Completamente automatizado**: No requiere intervención manual
- ✅ **Calidad de datos**: Nomenclatura consistente y validación
- ✅ **Siempre actualizado**: Se actualiza mensualmente con los datos más recientes
- ✅ **Interactivo**: Aplicación web para exploración de datos
- ✅ **Múltiples formatos**: Archivos RDS, CSV y Stata disponibles
- ✅ **Código abierto**: Todo el código disponible en GitHub

## 📈 Impacto

Este proyecto proporciona a investigadores, formuladores de políticas y ciudadanos:

- Tendencias históricas de precios de bienes básicos
- Recolección automatizada de datos de fuentes oficiales
- Herramientas interactivas para análisis económico
- Acceso abierto a datos limpios y estandarizados

## 📞 Contacto y contribuciones

Para comentarios, sugerencias o contribuciones:
- **Email**: rodriguezramirez@worldbank.org
- **Issues**: <https://github.com/RRMaximiliano/inide-canasta-basica/issues>
- **Fuente de datos**: INIDE Nicaragua

---

*Mantenido por @RRMaximiliano | Última actualización: 2026-01-28*
