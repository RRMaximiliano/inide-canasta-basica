
<!-- README.md is generated from README.Rmd. Please edit that file -->

# Canasta Básica de Nicaragua

<!-- badges: start -->
<!-- badges: end -->

Este repositorio contiene todos los datos disponibles de la canasta
básica de Nicaragua desde septiembre del año 2007 a diciembre del año
2021. Los datos se encuentran en la subcaprta `data` y también están
disponibles por cada mes en la subcarpeta `data/monthly`.

``` r
canasta_basica
#> # A tibble: 9,116 x 10
#>    yymm       year month url           row   bien   medida cantidad precio total
#>    <glue>    <int> <fct> <chr>         <chr> <chr>  <chr>     <dbl>  <dbl> <dbl>
#>  1 CB2007Sep  2007 Sep   https://www.~ 1     Arroz  Libra        38    6.1  231.
#>  2 CB2007Sep  2007 Sep   https://www.~ 2     Frijol Libra        34   10.5  355.
#>  3 CB2007Sep  2007 Sep   https://www.~ 3     Azúcar Libra        30    4.8  145.
#>  4 CB2007Sep  2007 Sep   https://www.~ 4     Aceite Litro         7   24.1  169.
#>  5 CB2007Sep  2007 Sep   https://www.~ 5     Posta~ Libra         8   32.9  263.
#>  6 CB2007Sep  2007 Sep   https://www.~ 6     Posta~ Libra         5   30    150.
#>  7 CB2007Sep  2007 Sep   https://www.~ 7     Carne~ Libra         8   17    136.
#>  8 CB2007Sep  2007 Sep   https://www.~ 8     Pesca~ Libra         9   35.6  320.
#>  9 CB2007Sep  2007 Sep   https://www.~ 9     Leche~ Litro        30   10.5  315 
#> 10 CB2007Sep  2007 Sep   https://www.~ 10    Huevos Docena        7   21.4  150.
#> # ... with 9,106 more rows
```

Cada base de datos contiene las siguientes variables:

-   `yymm`: Año - Mes de la canasta básica.
-   `year`: Año.
-   `month`: Mes.
-   `url`: URL de descarga de la página oficial del INIDE.
-   `row`: ID del bien. En total se encuentran 53 bienes.
-   `bien`: Nombre del bien.
-   `medida`: Medida oficial de consumo.
-   `cantidad`: Cantidad de consumo (en medida).
-   `precio`: Precio por medida.
-   `total`: Total de consumo.

La base de datos mantiene los nombres originales de cada bien que es
incluído en la canasta básica. Por ejemplo, para los años 2007 al 2009,
se mantuvo el nombre de “Pescado” y fue cambiado por “Chuleta de
Pescado” en los años siguients. Me queda limpiar estas discrepancias.

## Ejemplos

![](figures/arroz.png)<!-- -->![](figures/queso_seco.png)<!-- -->

## Comentarios y sugerencias

Para realizar comentarios o sugerencias sobre la base de datos puedes
escribirme a <rodriguezramirez@worldbank.org> o abrir un issue en este
repositorio:
<https://github.com/RRMaximiliano/inide-canasta-basica/issues>
