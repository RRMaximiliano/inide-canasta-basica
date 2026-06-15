
library(shiny)
library(bslib)
library(bsicons)
library(dplyr)
library(readr)
library(ggplot2)
library(lubridate)
library(forcats)
library(stringr)
library(scales)
library(DT)

# Get Data ----------------------------------------------------------------

# Load cleaned data (cleaning, categories and real prices are applied during
# data collection - see R/compile_canasta.R)
data <- read_rds("data/CB_FULL.rds")

month_levels <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                  "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")

if(!"ym" %in% names(data)) {
  data <- data %>%
    mutate(ym = ym(paste0(year, "-", as.numeric(month))))
}

# Base year for real (inflation-adjusted) prices (see R/ipc.R)
IPC_BASE_YEAR <- 2024
has_estimado  <- any(data$ipc_estimado)

# Single UI accent (royal blue) + a restrained categorical palette for the
# 3-series chart, and semantic colors for the monthly delta.
ACCENT  <- "#2563eb"
CAT_COLORS <- c(
  "Alimentos"      = "#2563eb",
  "Usos del Hogar" = "#f59e0b",
  "Vestuario"      = "#db2777"
)
COLOR_UP   <- "#d97706"  # cost rose (amber, unfavorable)
COLOR_DOWN <- "#059669"  # cost fell (emerald, favorable)

# Last data point and coverage --------------------------------------------

ordered_all <- data %>%
  arrange(year, match(as.character(month), month_levels))

last_data_point <- ordered_all %>% slice(n())
first_data_point <- ordered_all %>% slice(1)

last_update_text <- paste(last_data_point$month, last_data_point$year)
coverage_text <- paste0(first_data_point$month, " ", first_data_point$year,
                        " a ", last_data_point$month, " ", last_data_point$year)
app_updated_text <- format(Sys.Date(), "%d/%m/%Y")

# Good choices grouped by official category (renders as optgroups)
good_choices <- data %>%
  distinct(categoria, good) %>%
  arrange(categoria, good)
choices_list <- split(good_choices$good, good_choices$categoria)

# Static summaries (independent of the selected good) ---------------------

grouped_data <- data %>%
  group_by(year, month, ym) %>%
  summarize(
    total      = sum(total, na.rm = TRUE),
    total_real = sum(total_real, na.rm = TRUE),
    .groups    = "drop"
  ) %>%
  arrange(ym)

categoria_data <- data %>%
  group_by(ym, categoria) %>%
  summarize(
    total      = sum(total, na.rm = TRUE),
    total_real = sum(total_real, na.rm = TRUE),
    .groups    = "drop"
  )

n_months <- nrow(grouped_data)

price_choices <- c("nominal", "real")
names(price_choices) <- c("Nominal",
                          paste0("Real (córdobas de ", IPC_BASE_YEAR, ")"))

# Theme -------------------------------------------------------------------

app_theme <- bs_theme(
  version = 5,
  primary = ACCENT,
  base_font = font_google("Geist"),
  heading_font = font_google("Geist"),
  code_font = font_google("Geist Mono"),
  "border-radius" = "0.75rem"
)

# Page chrome refinements (light gray page + crisp white hairline cards, strong
# weight hierarchy, subtle export buttons). Mode-aware via [data-bs-theme].
app_css <- "
[data-bs-theme='light']{ --page-bg:#f4f5f7; --card-bg:#ffffff; --card-bd:#e7e9ee;
  --kpi-label:#667085; --kpi-icon:#98a2b3; --shadow:0 1px 2px rgba(16,24,40,.05),0 1px 3px rgba(16,24,40,.05); }
[data-bs-theme='dark']{ --page-bg:#0d0f13; --card-bg:#16191e; --card-bd:#23272e;
  --kpi-label:#9aa3af; --kpi-icon:#6b7480; --shadow:none; }
body{ background:var(--page-bg); }
.bslib-value-box, .card{ background:var(--card-bg)!important; border:1px solid var(--card-bd)!important;
  box-shadow:var(--shadow)!important; }
.bslib-value-box .value-box-title{ color:var(--kpi-label)!important; font-weight:500; font-size:.78rem; letter-spacing:.005em; margin-bottom:.1rem; }
.bslib-value-box .value-box-value{ font-weight:700; font-size:1.9rem; letter-spacing:-.022em; }
.bslib-value-box .value-box-area p{ color:var(--kpi-label); font-size:.74rem; margin:.1rem 0 0; }
.kpi-ic{ color:var(--kpi-icon); margin-right:.4rem; }
.nav-tabs .nav-link{ color:var(--kpi-label); font-weight:500; }
.nav-tabs .nav-link.active{ color:var(--bs-primary); font-weight:600; }
.dt-buttons{ float:none!important; margin-bottom:.6rem; }
.dt-buttons .btn{ font-size:.74rem!important; font-weight:500!important; padding:.2rem .65rem!important;
  border-radius:.45rem!important; background:transparent!important; color:var(--kpi-label)!important;
  border:1px solid var(--card-bd)!important; box-shadow:none!important; margin-right:.35rem; }
.dt-buttons .btn:hover{ background:var(--bs-primary)!important; color:#fff!important; border-color:var(--bs-primary)!important; }
table.dataTable{ font-size:.83rem; }
table.dataTable thead th{ font-weight:600!important; color:var(--kpi-label)!important; border-bottom:1px solid var(--card-bd)!important; }
table.dataTable td{ border-top:1px solid var(--card-bd)!important; }
.dataTables_filter input{ border:1px solid var(--card-bd)!important; border-radius:.45rem!important; }
.dataTables_info, .dataTables_paginate{ font-size:.78rem; color:var(--kpi-label); }
"

# ggplot theme that adapts to the active light/dark mode. Plots render on a
# transparent background so they sit cleanly on the card in either mode.
gg_theme <- function(pal, base = 14) {
  theme_minimal(base_size = base) +
    theme(
      text = element_text(color = pal$fg),
      axis.text = element_text(color = pal$muted, size = rel(0.85)),
      axis.title.y = element_text(color = pal$muted, size = rel(0.8)),
      axis.title.x = element_blank(),
      axis.ticks = element_blank(),
      plot.title = element_text(color = pal$fg, face = "bold", size = rel(1.15)),
      plot.subtitle = element_text(color = pal$muted, size = rel(0.92)),
      plot.caption = element_text(color = pal$faint, size = rel(0.78)),
      panel.grid.major.x = element_blank(),
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(color = pal$grid, linewidth = 0.4),
      plot.background = element_rect(fill = "transparent", color = NA),
      panel.background = element_rect(fill = "transparent", color = NA),
      legend.position = "bottom",
      legend.title = element_blank(),
      legend.text = element_text(color = pal$fg, size = rel(0.85)),
      plot.margin = margin(10, 14, 4, 4)
    )
}

# UI ----------------------------------------------------------------------

ui <- page_sidebar(
  title = tags$div(
    tags$span("Canasta Básica de Nicaragua",
              style = "font-weight:600;"),
    tags$span(
      sprintf("Precios mensuales del INIDE, %s", coverage_text),
      style = "display:block; font-size:0.72rem; font-weight:400; opacity:0.7;"
    )
  ),
  theme = app_theme,
  fillable = FALSE,

  sidebar = sidebar(
    width = 320,
    radioButtons(
      "priceType",
      "Tipo de precio",
      choices = price_choices,
      selected = "nominal"
    ),
    selectInput(
      "good",
      "Bien de la canasta",
      choices = choices_list,
      selected = "Queso seco"
    ),
    downloadButton(
      "download1",
      "Descargar tabla (CSV)",
      class = "btn-outline-primary btn-sm",
      icon = icon("download")
    ),
    tags$hr(style = "opacity:0.15;"),
    accordion(
      open = FALSE,
      accordion_panel(
        "Acerca de la canasta",
        icon = bs_icon("info-circle"),
        tags$p("La Canasta Básica de Nicaragua reúne 53 productos en tres grupos: alimentos, usos del hogar y vestuario. Su cobertura se restringe al área urbana de Managua."),
        tags$p("La versión vigente (2005) cubre 2,455 calorías diarias por persona para un hogar de seis miembros con actividad física moderada."),
        tags$p(sprintf("Los precios reales están ajustados por inflación a córdobas constantes de %d con el IPC de Nicaragua (FMI / IFS, base 2010 = 100).", IPC_BASE_YEAR))
      )
    ),
    tags$div(
      style = "margin-top:auto; font-size:0.78rem; opacity:0.7; line-height:1.4;",
      tags$div(tags$strong("Datos hasta: "), last_update_text),
      tags$div(tags$strong("App actualizada: "), app_updated_text),
      tags$div("Fuente: INIDE")
    ),
    input_dark_mode(id = "mode", mode = "light")
  ),

  tags$head(tags$style(HTML(app_css))),

  # KPI header
  layout_columns(
    fill = FALSE,
    col_widths = c(3, 3, 3, 3),
    value_box(
      title = tags$span(tags$span(bs_icon("cash-stack"), class = "kpi-ic"),
                        "Costo de la canasta"),
      value = textOutput("kpi_total"),
      textOutput("kpi_period")
    ),
    value_box(
      title = tags$span(tags$span(bs_icon("graph-up-arrow"), class = "kpi-ic"),
                        "Variación mensual"),
      value = uiOutput("kpi_change"),
      "vs. mes anterior"
    ),
    value_box(
      title = tags$span(tags$span(bs_icon("calendar3"), class = "kpi-ic"),
                        "Cobertura"),
      value = paste(n_months, "meses"),
      coverage_text
    ),
    value_box(
      title = tags$span(tags$span(bs_icon("basket"), class = "kpi-ic"),
                        "Bienes monitoreados"),
      value = "53",
      "en 3 categorías oficiales"
    )
  ),

  navset_card_tab(
    id = "view",
    nav_panel(
      "Por bien",
      plotOutput("plotBien", height = "460px"),
      tags$hr(style = "opacity:0.12;"),
      DT::DTOutput("tableBien")
    ),
    nav_panel(
      "Por categoría",
      plotOutput("plotCategoria", height = "460px"),
      tags$hr(style = "opacity:0.12;"),
      DT::DTOutput("tableCategoria")
    ),
    nav_panel(
      "Canasta total",
      plotOutput("plotCanasta", height = "460px"),
      tags$hr(style = "opacity:0.12;"),
      DT::DTOutput("tableCanasta")
    )
  )
)

# Server ------------------------------------------------------------------

server <- function(input, output, session) {

  # Nominal vs real columns / labels
  price_info <- reactive({
    if (identical(input$priceType, "real")) {
      list(col = "precio_real", totcol = "total_real",
           ylab = paste0("Córdobas constantes de ", IPC_BASE_YEAR),
           suffix = paste0(" (reales, córdobas de ", IPC_BASE_YEAR, ")"))
    } else {
      list(col = "precio", totcol = "total",
           ylab = "Córdobas (nominales)", suffix = " (nominal)")
    }
  })

  # Palette that follows the light/dark toggle (plots are transparent-bg)
  palette_mode <- reactive({
    if (identical(input$mode, "dark")) {
      list(fg = "#e9ecef", muted = "#9aa3af", faint = "#6b7480", grid = "#FFFFFF14")
    } else {
      list(fg = "#1f2328", muted = "#667085", faint = "#98a2b3", grid = "#00000012")
    }
  })

  plot_caption <- reactive({
    if (identical(input$priceType, "real")) {
      base <- "Fuente: INIDE | IPC: FMI/IFS vía DBnomics"
      if (has_estimado) base <- paste0(base, "\nÚltimos meses: IPC estimado")
      base
    } else {
      "Fuente: INIDE"
    }
  })

  filtered_data <- reactive({
    data %>% filter(good == input$good)
  }) %>%
    bindCache(input$good)

  # KPI: total cost ---------------------------------------------------------
  latest_totals <- reactive({
    info <- price_info()
    v <- grouped_data[[info$totcol]]
    list(latest = v[length(v)], prev = v[length(v) - 1])
  })

  output$kpi_total <- renderText({
    paste0("C$ ", format(round(latest_totals()$latest, 0), big.mark = ","))
  })

  output$kpi_period <- renderText({
    paste("Total,", last_update_text)
  })

  output$kpi_change <- renderUI({
    lt <- latest_totals()
    pct <- (lt$latest - lt$prev) / lt$prev * 100
    up <- pct >= 0
    tags$span(
      style = paste0("color:", if (up) COLOR_UP else COLOR_DOWN, ";"),
      bs_icon(if (up) "arrow-up-right" else "arrow-down-right"),
      sprintf(" %+.1f%%", pct)
    )
  })

  # Por bien ----------------------------------------------------------------
  output$plotBien <- renderPlot({
    info <- price_info()
    pal <- palette_mode()
    title_lab <- sprintf("Precio de %s de %s%s",
                         unique(filtered_data()$medida)[1], input$good, info$suffix)
    subtitle_lab <- sprintf("%s - %s",
                            min(filtered_data()$year), max(filtered_data()$year))

    filtered_data() %>%
      ggplot(aes(ym, .data[[info$col]])) +
      geom_area(fill = ACCENT, alpha = 0.10) +
      geom_line(color = ACCENT, linewidth = 1.1) +
      scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.05))) +
      labs(x = NULL, y = info$ylab, title = title_lab,
           subtitle = subtitle_lab, caption = plot_caption()) +
      gg_theme(pal)
  }, bg = "transparent")

  output$tableBien <- DT::renderDT({
    info <- price_info()
    filtered_data() %>%
      arrange(desc(ym)) %>%
      select(year, month, good, categoria, medida, cantidad,
             precio = all_of(info$col), total = all_of(info$totcol)) %>%
      DT::datatable(
        extensions = "Buttons",
        options = list(dom = "Bfrtip",
                       buttons = c("copy", "csv", "excel"),
                       pageLength = 8),
        rownames = FALSE, class = "table-sm"
      ) %>%
      formatRound(columns = c("precio", "total"), digits = 2)
  })

  output$download1 <- downloadHandler(
    filename = function() {
      safe_good <- str_replace_all(input$good, "[^[:alnum:]]+", "_")
      paste0("inide_canasta_basica_", safe_good, "_", Sys.Date(), ".csv")
    },
    content = function(file) {
      write.csv(filtered_data(), file, row.names = FALSE)
    }
  )

  # Por categoría -----------------------------------------------------------
  output$plotCategoria <- renderPlot({
    info <- price_info()
    pal <- palette_mode()
    categoria_data %>%
      ggplot(aes(ym, .data[[info$totcol]], color = categoria)) +
      geom_line(linewidth = 1) +
      scale_color_manual(values = CAT_COLORS) +
      scale_y_continuous(labels = comma) +
      labs(x = NULL, y = info$ylab,
           title = "Costo de la canasta por categoría",
           subtitle = names(price_choices)[price_choices == input$priceType],
           caption = plot_caption()) +
      gg_theme(pal)
  }, bg = "transparent")

  output$tableCategoria <- DT::renderDT({
    info <- price_info()
    categoria_data %>%
      arrange(desc(ym), categoria) %>%
      select(ym, categoria, total = all_of(info$totcol)) %>%
      DT::datatable(
        extensions = "Buttons",
        options = list(dom = "Bfrtip",
                       buttons = c("copy", "csv", "excel"),
                       pageLength = 9),
        rownames = FALSE, class = "table-sm"
      ) %>%
      formatRound(columns = c("total"), digits = 1)
  })

  # Canasta total -----------------------------------------------------------
  output$plotCanasta <- renderPlot({
    info <- price_info()
    pal <- palette_mode()
    grouped_data %>%
      ggplot(aes(ym, .data[[info$totcol]])) +
      geom_area(fill = ACCENT, alpha = 0.10) +
      geom_line(color = ACCENT, linewidth = 1.1) +
      scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.05))) +
      labs(x = NULL, y = info$ylab,
           title = paste0("Precio total de la canasta básica", info$suffix),
           caption = plot_caption()) +
      gg_theme(pal)
  }, bg = "transparent")

  output$tableCanasta <- DT::renderDT({
    info <- price_info()
    grouped_data %>%
      arrange(desc(ym)) %>%
      select(year, month, total = all_of(info$totcol)) %>%
      DT::datatable(
        extensions = "Buttons",
        options = list(dom = "Bfrtip",
                       buttons = c("copy", "csv", "excel"),
                       pageLength = 8),
        rownames = FALSE, class = "table-sm"
      ) %>%
      formatRound(columns = c("total"), digits = 1)
  })
}

shinyApp(ui, server)
