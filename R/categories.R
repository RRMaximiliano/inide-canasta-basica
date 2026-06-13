# Category dimension for the canasta basica.
# SINGLE SOURCE OF TRUTH for mapping each of the 53 standardized goods to one
# of INIDE's three official groups. Sourced by R/compile_canasta.R.
# Requires: dplyr.
#
# INIDE's canasta basica de 53 productos is officially organized in three
# groups (53 = 23 + 15 + 15):
#   - "Alimentos"        : the 23 food products (official item numbers 1-23)
#   - "Usos del Hogar"   : household goods and services, incl. rent, power,
#                          water and transport (official item numbers 24-38)
#   - "Vestuario"        : clothing and footwear (official item numbers 39-53)
#
# The mapping is keyed on the *standardized* good name produced by
# clean_canasta_data() (so it is robust to row reordering on the source site).
# If INIDE ever revises the basket, add the new good name here; the data
# validation gate (scripts/validate_data.R) fails on any good without a
# category, so a gap cannot ship silently.

CANASTA_CATEGORIAS <- c(
  # --- Alimentos (1-23) ---
  "Arroz"                = "Alimentos",
  "Frijol"               = "Alimentos",
  "Azúcar"               = "Alimentos",
  "Aceite"               = "Alimentos",
  "Posta de res"         = "Alimentos",
  "Posta de cerdo"       = "Alimentos",
  "Carne de aves"        = "Alimentos",
  "Chuleta de pescado"   = "Alimentos",
  "Leche"                = "Alimentos",
  "Huevos"               = "Alimentos",
  "Queso seco"           = "Alimentos",
  "Tortilla"             = "Alimentos",
  "Pinolillo"            = "Alimentos",
  "Pastas alimenticias"  = "Alimentos",
  "Pan"                  = "Alimentos",
  "Tomate de cocinar"    = "Alimentos",
  "Cebolla blanca"       = "Alimentos",
  "Papas"                = "Alimentos",
  "Ayote"                = "Alimentos",
  "Chiltoma"             = "Alimentos",
  "Plátano verde"        = "Alimentos",
  "Naranja"              = "Alimentos",
  "Repollo"              = "Alimentos",

  # --- Usos del Hogar (24-38) ---
  "Jabón de lavar ropa"  = "Usos del Hogar",
  "Detergente"           = "Usos del Hogar",
  "Pasta dental"         = "Usos del Hogar",
  "Fósforos"             = "Usos del Hogar",
  "Escoba"               = "Usos del Hogar",
  "Papel higiénico"      = "Usos del Hogar",
  "Jabón de baño"        = "Usos del Hogar",
  "Toallas sanitarias"   = "Usos del Hogar",
  "Desodorante nacional" = "Usos del Hogar",
  "Cepillo dental"       = "Usos del Hogar",
  "Alquiler"             = "Usos del Hogar",
  "Gas butano"           = "Usos del Hogar",
  "Luz eléctrica"        = "Usos del Hogar",
  "Agua"                 = "Usos del Hogar",
  "Transporte"           = "Usos del Hogar",

  # --- Vestuario (39-53) ---
  "Pantalón largo de tela de jeans (Hombre)"  = "Vestuario",
  "Camisa manga corta"                        = "Vestuario",
  "Calzoncillos"                              = "Vestuario",
  "Calcetines (Hombre)"                       = "Vestuario",
  "Zapato de cuero natural"                   = "Vestuario",
  "Blusa manga corta"                         = "Vestuario",
  "Pantalón largo de tela de jeans (Mujeres)" = "Vestuario",
  "Vestido entero"                            = "Vestuario",
  "Calzones/ Bikinis"                         = "Vestuario",
  "Brassier/sostén"                           = "Vestuario",
  "Sandalias de cuero sintético"              = "Vestuario",
  "Traje completo"                            = "Vestuario",
  "Calzones"                                  = "Vestuario",
  "Calcetines (Niños y Niñas)"                = "Vestuario",
  "Zapato de cuero sintético"                 = "Vestuario"
)

# Levels in official display order
CANASTA_CATEGORIA_LEVELS <- c("Alimentos", "Usos del Hogar", "Vestuario")

# Add a `categoria` factor column based on the standardized `good` name.
add_categoria <- function(data) {
  data %>%
    mutate(
      categoria = unname(CANASTA_CATEGORIAS[good]),
      categoria = factor(categoria, levels = CANASTA_CATEGORIA_LEVELS)
    )
}
