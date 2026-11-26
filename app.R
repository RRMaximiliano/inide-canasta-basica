
library(shiny)
library(bslib)
library(bsicons)
library(dplyr)
library(readr)
library(ggplot2)
library(ggiraph)
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

month_label <- function(d) paste(month_levels[month(d)], year(d))

# Base R only gained %||% in 4.4; the deploy runs R 4.3
`%||%` <- function(x, y) if (is.null(x)) y else x

# Base year for real (inflation-adjusted) prices (see R/ipc.R)
IPC_BASE_YEAR <- 2024

# Single UI accent (royal blue) + a restrained categorical palette for the
# 3-series charts, and semantic colors for price changes.
ACCENT  <- "#2563eb"
CAT_COLORS <- c(
  "Alimentos"      = "#2563eb",
  "Usos del Hogar" = "#f59e0b",
  "Vestuario"      = "#db2777"
)
SERIES_COLORS <- unname(CAT_COLORS)  # for up to 3 compared goods
COLOR_UP   <- "#d97706"  # cost rose (amber, unfavorable)
COLOR_DOWN <- "#059669"  # cost fell (emerald, favorable)
MAX_GOODS  <- 3

# Coverage, gaps and estimated IPC ----------------------------------------

first_ym <- min(data$ym)
last_ym  <- max(data$ym)
all_months <- seq(first_ym, last_ym, by = "month")
# Months INIDE never published. Charts get NA rows for them so lines break
# instead of drawing a straight segment across the hole.
missing_months <- all_months[!all_months %in% unique(data$ym)]

last_update_text <- month_label(last_ym)
coverage_text <- paste(month_label(first_ym), "a", last_update_text)

# Months whose real prices use a carried-forward (estimated) IPC
est_months <- sort(unique(data$ym[data$ipc_estimado]))
latest_estimado <- last_ym %in% est_months
last_official_ipc <- if (any(!data$ipc_estimado)) {
  month_label(max(data$ym[!data$ipc_estimado]))
} else NA_character_

# Publication date: the deploy workflow writes data/build_info.txt. Fall back
# to the data file's date. Never Sys.Date(): that is the date the server
# process last started, which on shinyapps.io is whenever the app woke up.
app_published_text <- tryCatch({
  if (file.exists("data/build_info.txt")) {
    format(as.Date(readLines("data/build_info.txt", n = 1)), "%d/%m/%Y")
  } else {
    format(as.Date(file.mtime("data/CB_FULL.rds")), "%d/%m/%Y")
  }
}, error = function(e) format(as.Date(file.mtime("data/CB_FULL.rds")), "%d/%m/%Y"))

# Good choices grouped by official category (renders as optgroups)
good_choices <- data %>%
  distinct(categoria, good) %>%
  arrange(categoria, good)
choices_list <- split(good_choices$good, good_choices$categoria)
n_goods <- n_distinct(data$good)
n_cats  <- n_distinct(data$categoria)

# Static summaries (independent of the selected good) ---------------------

add_year_month <- function(df) {
  df %>% mutate(year = year(ym), month = month_levels[month(ym)], .before = 1)
}

grouped_data <- data %>%
  group_by(ym) %>%
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

# The KPI compares against the previous *published* month, which is not the
# previous calendar month when INIDE skips one, so name it explicitly.
prev_ym <- grouped_data$ym[n_months - 1]
prev_period_text <- paste("vs.", month_label(prev_ym))
yago_ym <- last_ym %m-% years(1)

price_choices <- c("nominal", "real")
names(price_choices) <- c("Nominal",
                          paste0("Real (córdobas de ", IPC_BASE_YEAR, ")"))

cat_scale_choices <- c("Córdobas" = "cordobas",
                       "Índice (inicio = 100)" = "indice",
                       "Participación (%)" = "share")

# Inputs saved in the shareable URL
BOOKMARK_INPUTS <- c("priceType", "good", "range", "view", "catScale")

# Helpers -----------------------------------------------------------------

# Add NA rows for every month in the full calendar (per group), so a skipped
# month breaks the line.
pad_months <- function(df, group = NULL) {
  grid <- if (is.null(group)) {
    tibble(ym = all_months)
  } else {
    g <- unique(df[[group]])
    tibble(ym = rep(all_months, times = length(g)),
           !!group := rep(g, each = length(all_months)))
  }
  left_join(grid, df, by = c("ym", group))
}

# Dashed segments across unpublished months: connect the last value before a
# gap to the first value after it, so the month after a gap stays visible
# (a lone point between NAs draws no line) while the gap still reads as one.
gap_bridges <- function(df, group = NULL) {
  df <- df %>% filter(!is.na(value))
  if (!is.null(group)) df <- df %>% group_by(.data[[group]])
  df %>%
    arrange(ym, .by_group = TRUE) %>%
    mutate(ym_end = lead(ym), value_end = lead(value)) %>%
    filter(!is.na(ym_end),
           (year(ym_end) * 12 + month(ym_end)) - (year(ym) * 12 + month(ym)) > 1) %>%
    ungroup()
}

bridge_layer <- function(bridges, color = NULL) {
  if (nrow(bridges) == 0) return(NULL)
  aes_end <- aes(xend = ym_end, yend = value_end)
  if (is.null(color)) {
    geom_segment(aes_end, data = bridges, linetype = "22",
                 linewidth = 0.7, alpha = 0.6)
  } else {
    geom_segment(aes_end, data = bridges, linetype = "22",
                 linewidth = 0.7, alpha = 0.6, color = color)
  }
}

# Date axis: years only when every break is a January, else "Ene 2025"
date_labels <- function(x) {
  ok <- !is.na(x)
  out <- rep("", length(x))
  out[ok] <- if (all(month(x[ok]) == 1)) as.character(year(x[ok])) else month_label(x[ok])
  out
}
x_dates <- function() scale_x_date(labels = date_labels)

fmt_cs <- function(x, digits = 2) {
  paste0("C$ ", formatC(x, format = "f", digits = digits, big.mark = ","))
}

# Shaded band + label over months whose real prices use an estimated IPC
est_layer <- function(r, pal) {
  e <- est_months[est_months >= r[1] & est_months <= r[2]]
  if (length(e) == 0) return(NULL)
  list(
    annotate("rect", xmin = min(e) - 15, xmax = max(e) + 15,
             ymin = -Inf, ymax = Inf, fill = pal$est),
    annotate("text", x = min(e) - 10, y = Inf, label = "IPC estimado",
             hjust = 0, vjust = 1.6, size = 3, color = pal$muted)
  )
}

# Hover points: invisible until hovered, carry the tooltip
hover_points <- function(mapping, ...) {
  geom_point_interactive(mapping, size = 2.4, alpha = 0, na.rm = TRUE, ...)
}

TOOLTIP_CSS <- paste0(
  "background:#111827;color:#f9fafb;padding:6px 9px;border-radius:6px;",
  "font-family:Geist,system-ui,sans-serif;font-size:12px;line-height:1.35;"
)

# Phones get a narrower, taller canvas so text stays legible once the SVG is
# scaled to the screen width.
as_girafe <- function(p, mobile = FALSE) {
  girafe(
    ggobj = p,
    width_svg  = if (mobile) 4.2 else 9,
    height_svg = 4.4,
    bg = "transparent",
    options = list(
      opts_sizing(rescale = TRUE, width = 1),
      opts_tooltip(css = TOOLTIP_CSS, opacity = 1, use_fill = FALSE),
      opts_hover(css = "fill-opacity:1;stroke-opacity:1;"),
      opts_selection(type = "none"),
      opts_toolbar(saveaspng = FALSE)
    )
  )
}

COL_LABELS <- c(year = "Año", month = "Mes", good = "Bien",
                categoria = "Categoría", medida = "Medida",
                cantidad = "Cantidad", precio = "Precio", total = "Total",
                indice = "Índice", participacion = "Participación (%)")

dt_table <- function(df, round_cols, digits = 2, page_length = 8) {
  DT::datatable(
    df,
    colnames = unname(ifelse(names(df) %in% names(COL_LABELS),
                             COL_LABELS[names(df)], names(df))),
    extensions = "Buttons",
    options = list(dom = "Bfrtip",
                   buttons = c("copy", "csv", "excel"),
                   pageLength = page_length),
    rownames = FALSE, class = "table-sm"
  ) %>%
    formatRound(columns = round_cols, digits = digits)
}

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
.bslib-value-box .value-box-area p, .bslib-value-box .value-box-area .kpi-sub{ color:var(--kpi-label); font-size:.74rem; margin:.1rem 0 0; }
.bslib-value-box .value-box-area .value-box-value{ color:var(--bs-body-color); font-weight:700; font-size:1.9rem; letter-spacing:-.022em; margin:0; }
.kpi-ic{ color:var(--kpi-icon); margin-right:.4rem; }
.kpi-est{ color:#d97706; font-weight:600; }
.nav-tabs .nav-link{ color:var(--kpi-label); font-weight:500; }
.nav-tabs .nav-link.active{ color:var(--bs-primary); font-weight:600; }
.tab-note{ color:var(--kpi-label); font-size:.8rem; margin:.2rem 0 .6rem; }
.cat-scale .shiny-options-group{ font-size:.82rem; }
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
.irs--shiny .irs-bar{ background:var(--bs-primary); border-color:var(--bs-primary); }
.irs--shiny .irs-from, .irs--shiny .irs-to, .irs--shiny .irs-single{ font-size:.66rem; }
.irs--shiny{ margin:0 8px; }
/* Chart boxes follow the SVG canvas (9 x 4.4 in; 4.2 x 4.4 on phones, same
   700px cutoff as is_mobile() in the server) so there is no empty band. */
#plotBien, #plotCategoria, #plotCanasta{ aspect-ratio: 9 / 4.4; height:auto!important; }
@media (max-width: 699.98px){
  #plotBien, #plotCategoria, #plotCanasta{ aspect-ratio: 4.2 / 4.4; }
}
"

# ggplot theme that adapts to the active light/dark mode. Plots render on a
# transparent background so they sit cleanly on the card in either mode.
gg_theme <- function(pal, base = 11) {
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

ui <- function(request) {
  page_sidebar(
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
      sliderInput(
        "range",
        "Período",
        min = first_ym, max = last_ym,
        value = c(first_ym, last_ym),
        timeFormat = "%m/%Y", ticks = FALSE
      ),
      selectizeInput(
        "good",
        sprintf("Bienes de la canasta (hasta %d)", MAX_GOODS),
        choices = choices_list,
        selected = "Queso seco",
        multiple = TRUE,
        options = list(maxItems = MAX_GOODS, plugins = list("remove_button"))
      ),
      downloadButton(
        "download_all",
        "Descargar datos completos (CSV)",
        class = "btn-outline-primary btn-sm",
        icon = icon("download")
      ),
      tags$hr(style = "opacity:0.15;"),
      accordion(
        open = FALSE,
        accordion_panel(
          "Acerca de la canasta",
          icon = bs_icon("info-circle"),
          tags$p(sprintf("La Canasta Básica de Nicaragua reúne %d productos en %d grupos: alimentos, usos del hogar y vestuario. Su cobertura se restringe al área urbana de Managua.", n_goods, n_cats)),
          tags$p("La versión vigente (2005) cubre 2,455 calorías diarias por persona para un hogar de seis miembros con actividad física moderada."),
          tags$p(sprintf("Los precios reales están ajustados por inflación a córdobas constantes de %d con el IPC de Nicaragua (FMI / IFS, base 2010 = 100).", IPC_BASE_YEAR)),
          if (length(est_months) > 0 && !is.na(last_official_ipc))
            tags$p(sprintf("El último IPC oficial disponible es de %s. Los meses posteriores (sombreados como «IPC estimado») usan ese mismo valor, así que sus precios reales siguen la misma tendencia que los nominales.", last_official_ipc)),
          if (length(missing_months) > 0)
            tags$p(sprintf("INIDE no ha publicado: %s. Los gráficos dejan esos meses en blanco.",
                           paste(month_label(missing_months), collapse = ", ")))
        )
      ),
      tags$div(
        style = "margin-top:auto; font-size:0.78rem; opacity:0.7; line-height:1.4;",
        tags$div(tags$strong("Datos hasta: "), last_update_text),
        tags$div(tags$strong("App publicada: "), app_published_text),
        tags$div("Fuente: INIDE")
      ),
      input_dark_mode(id = "mode", mode = "light")
    ),

    tags$head(
      tags$style(HTML(app_css)),
      # Report the window width so charts can switch to a phone layout
      tags$script(HTML("
        $(document).on('shiny:connected', function() {
          Shiny.setInputValue('win_w', window.innerWidth);
        });
        $(window).on('resize', function() {
          clearTimeout(window.__winW);
          window.__winW = setTimeout(function() {
            Shiny.setInputValue('win_w', window.innerWidth);
          }, 400);
        });"))
    ),

    # KPI header
    layout_columns(
      fill = FALSE,
      col_widths = c(3, 3, 3, 3),
      value_box(
        title = tags$span(tags$span(bs_icon("cash-stack"), class = "kpi-ic"),
                          "Costo de la canasta"),
        value = textOutput("kpi_total"),
        uiOutput("kpi_period", class = "kpi-sub")
      ),
      value_box(
        title = tags$span(tags$span(bs_icon("graph-up-arrow"), class = "kpi-ic"),
                          "Variación"),
        value = uiOutput("kpi_change"),
        uiOutput("kpi_change_sub", class = "kpi-sub")
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
        value = as.character(n_goods),
        sprintf("en %d categorías oficiales", n_cats)
      )
    ),

    navset_card_tab(
      id = "view",
      nav_panel(
        "Por bien", value = "bien",
        girafeOutput("plotBien", height = "auto"),
        tags$hr(style = "opacity:0.12;"),
        DT::DTOutput("tableBien")
      ),
      nav_panel(
        "Por categoría", value = "categoria",
        tags$div(
          class = "cat-scale",
          radioButtons("catScale", NULL, choices = cat_scale_choices,
                       selected = "cordobas", inline = TRUE)
        ),
        girafeOutput("plotCategoria", height = "auto"),
        tags$hr(style = "opacity:0.12;"),
        DT::DTOutput("tableCategoria")
      ),
      nav_panel(
        "Canasta total", value = "total",
        girafeOutput("plotCanasta", height = "auto"),
        tags$hr(style = "opacity:0.12;"),
        DT::DTOutput("tableCanasta")
      ),
      nav_panel(
        "Mayores cambios", value = "cambios",
        uiOutput("movers_note"),
        DT::DTOutput("tableMovers")
      )
    )
  )
}

# Server ------------------------------------------------------------------

server <- function(input, output, session) {

  # Shareable URL: keep only the meaningful inputs in the query string
  observe({
    setBookmarkExclude(setdiff(names(input), BOOKMARK_INPUTS))
  })
  observe({
    for (i in BOOKMARK_INPUTS) input[[i]]
    session$doBookmark()
  })
  onBookmarked(function(url) updateQueryString(url))

  is_real <- reactive(identical(input$priceType, "real"))
  # Window width comes from a small script in the UI (see win_w)
  is_mobile <- reactive((input$win_w %||% 1200) < 700)

  # Nominal vs real columns / labels
  price_info <- reactive({
    if (is_real()) {
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
      list(fg = "#e9ecef", muted = "#9aa3af", faint = "#6b7480",
           grid = "#FFFFFF14", est = "#FFFFFF0D")
    } else {
      list(fg = "#1f2328", muted = "#667085", faint = "#98a2b3",
           grid = "#00000012", est = "#0000000A")
    }
  })

  # Selected period, snapped to whole months
  period <- reactive({
    r <- floor_date(as.Date(input$range %||% c(first_ym, last_ym)), "month")
    sort(r)
  })
  in_period <- function(df) {
    r <- period()
    df %>% filter(ym >= r[1], ym <= r[2])
  }
  period_text <- reactive(paste(month_label(period()[1]), "-",
                                month_label(period()[2])))

  # Caption: source, plus any unpublished months inside the period.
  # `real` = whether the plotted values depend on the IPC.
  plot_caption <- function(real = is_real()) {
    r <- period()
    parts <- if (real) "Fuente: INIDE | IPC: FMI/IFS vía DBnomics" else "Fuente: INIDE"
    g <- missing_months[missing_months >= r[1] & missing_months <= r[2]]
    if (length(g) > 0)
      parts <- c(parts, paste("Sin datos publicados por INIDE:",
                              paste(month_label(g), collapse = ", ")))
    paste(parts, collapse = "\n")
  }
  shade <- function(real = is_real()) {
    if (real) est_layer(period(), palette_mode()) else NULL
  }

  # KPIs --------------------------------------------------------------------
  latest_totals <- reactive({
    v <- grouped_data[[price_info()$totcol]]
    list(latest = v[length(v)], prev = v[length(v) - 1])
  })

  est_badge <- reactive({
    if (is_real() && latest_estimado)
      tags$span(" · IPC estimado", class = "kpi-est")
  })

  output$kpi_total <- renderText({
    paste0("C$ ", format(round(latest_totals()$latest, 0), big.mark = ","))
  })

  output$kpi_period <- renderUI({
    tagList(paste("Total,", last_update_text), est_badge())
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

  output$kpi_change_sub <- renderUI({
    tagList(prev_period_text, est_badge())
  })

  # Por bien ----------------------------------------------------------------
  goods_selected <- reactive({
    validate(need(length(input$good) > 0, "Selecciona al menos un bien."))
    input$good
  })

  goods_data <- reactive({
    data %>% filter(good %in% goods_selected())
  })

  output$plotBien <- renderGirafe({
    info <- price_info()
    pal <- palette_mode()
    goods <- goods_selected()
    df <- goods_data() %>%
      select(ym, good, medida, value = all_of(info$col))

    if (length(goods) == 1) {
      pd <- pad_months(df %>% select(ym, value)) %>%
        in_period() %>%
        mutate(tip = paste0(month_label(ym), "<br><b>", fmt_cs(value), "</b>"))
      title_lab <- sprintf("Precio de %s de %s%s",
                           df$medida[1], goods, info$suffix)
      p <- ggplot(pd, aes(ym, value)) +
        shade() +
        geom_ribbon(aes(ymin = 0, ymax = value), fill = ACCENT, alpha = 0.10, na.rm = TRUE) +
        geom_line(color = ACCENT, linewidth = 1.1, na.rm = TRUE) +
        bridge_layer(gap_bridges(pd), color = ACCENT) +
        hover_points(aes(tooltip = tip, data_id = as.character(ym)),
                     color = ACCENT) +
        scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.05))) +
        labs(x = NULL, y = info$ylab, title = title_lab,
             subtitle = period_text(), caption = plot_caption())
    } else {
      # Different units (libra, litro, unidad...) -> compare as an index
      pd <- pad_months(df %>% select(ym, good, value), group = "good") %>%
        in_period() %>%
        group_by(good) %>%
        mutate(value = value / first(na.omit(value)) * 100) %>%
        ungroup() %>%
        mutate(good = factor(good, levels = goods),
               tip = paste0(good, "<br>", month_label(ym),
                            "<br><b>", number(value, accuracy = 0.1), "</b>"))
      p <- ggplot(pd, aes(ym, value, color = good)) +
        shade() +
        geom_hline(yintercept = 100, color = pal$grid, linewidth = 0.6) +
        geom_line(linewidth = 1, na.rm = TRUE) +
        bridge_layer(gap_bridges(pd, "good")) +
        hover_points(aes(tooltip = tip, data_id = paste(good, ym))) +
        scale_color_manual(values = setNames(SERIES_COLORS[seq_along(goods)], goods)) +
        scale_y_continuous(labels = comma) +
        labs(x = NULL,
             y = sprintf("Índice (%s = 100)", month_label(period()[1])),
             title = paste0("Comparación de precios", info$suffix),
             subtitle = period_text(), caption = plot_caption())
    }
    as_girafe(p + x_dates() + gg_theme(pal), is_mobile())
  })

  output$tableBien <- DT::renderDT({
    info <- price_info()
    goods_data() %>%
      in_period() %>%
      arrange(desc(ym), good) %>%
      add_year_month() %>%
      select(year, month, good, categoria, medida, cantidad,
             precio = all_of(info$col), total = all_of(info$totcol)) %>%
      dt_table(c("precio", "total"), digits = 2)
  })

  output$download_all <- downloadHandler(
    filename = function() {
      paste0("inide_canasta_basica_", format(last_ym, "%Y-%m"), ".csv")
    },
    content = function(file) {
      write.csv(data, file, row.names = FALSE)
    }
  )

  # Por categoría -----------------------------------------------------------
  categoria_plot_data <- reactive({
    info <- price_info()
    scale_sel <- input$catScale %||% "cordobas"
    df <- categoria_data %>%
      select(ym, categoria, value = all_of(info$totcol)) %>%
      in_period()
    df <- switch(
      scale_sel,
      indice = df %>% group_by(categoria) %>% arrange(ym) %>%
        mutate(value = value / first(value) * 100) %>% ungroup(),
      share = df %>% group_by(ym) %>%
        mutate(value = value / sum(value) * 100) %>% ungroup(),
      df
    )
    df
  })

  output$plotCategoria <- renderGirafe({
    info <- price_info()
    pal <- palette_mode()
    scale_sel <- input$catScale %||% "cordobas"
    fmt <- switch(scale_sel,
                  indice = function(x) number(x, accuracy = 0.1),
                  share  = function(x) paste0(number(x, accuracy = 0.1), "%"),
                  function(x) fmt_cs(x, 0))
    ylab <- switch(scale_sel,
                   indice = sprintf("Índice (%s = 100)", month_label(period()[1])),
                   share  = "Participación en el costo total (%)",
                   info$ylab)
    # Shares are the same nominal or real (one deflator per month)
    uses_ipc <- is_real() && scale_sel != "share"

    pd <- pad_months(categoria_plot_data(), group = "categoria") %>%
      in_period() %>%
      mutate(tip = paste0(categoria, "<br>", month_label(ym),
                          "<br><b>", fmt(value), "</b>"))

    p <- ggplot(pd, aes(ym, value, color = categoria)) +
      shade(uses_ipc) +
      geom_line(linewidth = 1, na.rm = TRUE) +
      bridge_layer(gap_bridges(pd, "categoria")) +
      hover_points(aes(tooltip = tip, data_id = paste(categoria, ym))) +
      scale_color_manual(values = CAT_COLORS) +
      scale_y_continuous(labels = comma) +
      labs(x = NULL, y = ylab,
           title = "Costo de la canasta por categoría",
           subtitle = paste0(names(price_choices)[price_choices == input$priceType],
                             " · ", period_text()),
           caption = plot_caption(uses_ipc)) +
      gg_theme(pal)
    if (scale_sel == "indice")
      p <- p + geom_hline(yintercept = 100, color = pal$grid, linewidth = 0.6)
    as_girafe(p + x_dates(), is_mobile())
  })

  output$tableCategoria <- DT::renderDT({
    scale_sel <- input$catScale %||% "cordobas"
    col_name <- switch(scale_sel, indice = "indice", share = "participacion",
                       "total")
    categoria_plot_data() %>%
      arrange(desc(ym), categoria) %>%
      add_year_month() %>%
      select(year, month, categoria, value) %>%
      rename(!!col_name := value) %>%
      dt_table(col_name, digits = 1, page_length = 9)
  })

  # Canasta total -----------------------------------------------------------
  output$plotCanasta <- renderGirafe({
    info <- price_info()
    pal <- palette_mode()
    pd <- pad_months(grouped_data %>% select(ym, value = all_of(info$totcol))) %>%
      in_period() %>%
      mutate(tip = paste0(month_label(ym), "<br><b>", fmt_cs(value, 0), "</b>"))
    p <- ggplot(pd, aes(ym, value)) +
      shade() +
      geom_ribbon(aes(ymin = 0, ymax = value), fill = ACCENT, alpha = 0.10, na.rm = TRUE) +
      geom_line(color = ACCENT, linewidth = 1.1, na.rm = TRUE) +
      bridge_layer(gap_bridges(pd), color = ACCENT) +
      hover_points(aes(tooltip = tip, data_id = as.character(ym)),
                   color = ACCENT) +
      scale_y_continuous(labels = comma, expand = expansion(mult = c(0, 0.05))) +
      labs(x = NULL, y = info$ylab,
           title = paste0("Precio total de la canasta básica", info$suffix),
           subtitle = period_text(), caption = plot_caption()) +
      x_dates() +
      gg_theme(pal)
    as_girafe(p, is_mobile())
  })

  output$tableCanasta <- DT::renderDT({
    info <- price_info()
    grouped_data %>%
      in_period() %>%
      arrange(desc(ym)) %>%
      add_year_month() %>%
      select(year, month, total = all_of(info$totcol)) %>%
      dt_table("total", digits = 1)
  })

  # Mayores cambios ---------------------------------------------------------
  output$movers_note <- renderUI({
    tags$p(
      class = "tab-note",
      sprintf("Variación del precio de cada bien en %s frente a %s (último mes publicado) y frente a %s. Ordenado por la magnitud del cambio mensual.",
              last_update_text, month_label(prev_ym), month_label(yago_ym)),
      if (is_real() && latest_estimado)
        tags$span(" Precios reales con IPC estimado.", class = "kpi-est")
    )
  })

  output$tableMovers <- DT::renderDT({
    info <- price_info()
    p <- data %>% select(good, categoria, medida, ym, precio = all_of(info$col))
    at <- function(d) p %>% filter(ym == d) %>% select(good, precio)

    cur_lbl  <- paste("Precio", last_update_text)
    prev_lbl <- paste("Precio", month_label(prev_ym))
    chg_lbl  <- paste("Cambio vs", month_label(prev_ym), "(%)")
    yoy_lbl  <- paste("Cambio vs", month_label(yago_ym), "(%)")

    movers <- p %>%
      filter(ym == last_ym) %>%
      select(good, categoria, medida, actual = precio) %>%
      left_join(at(prev_ym) %>% rename(previo = precio), by = "good") %>%
      left_join(at(yago_ym) %>% rename(hace_un_ano = precio), by = "good") %>%
      mutate(cambio = (actual / previo - 1) * 100,
             cambio_12 = (actual / hace_un_ano - 1) * 100) %>%
      arrange(desc(abs(cambio))) %>%
      select(good, categoria, medida, previo, actual, cambio, cambio_12)

    DT::datatable(
      movers,
      colnames = c("Bien", "Categoría", "Medida", prev_lbl, cur_lbl,
                   chg_lbl, yoy_lbl),
      extensions = "Buttons",
      options = list(dom = "Bfrtip", buttons = c("copy", "csv", "excel"),
                     pageLength = 15, order = list()),
      rownames = FALSE, class = "table-sm"
    ) %>%
      formatRound(c("previo", "actual"), digits = 2) %>%
      formatRound(c("cambio", "cambio_12"), digits = 1) %>%
      formatStyle(c("cambio", "cambio_12"), fontWeight = "600",
                  color = styleInterval(0, c(COLOR_DOWN, COLOR_UP)))
  })
}

shinyApp(ui, server, enableBookmarking = "url")
