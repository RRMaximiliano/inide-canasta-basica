
library(shiny)
library(dplyr)
library(readr)
library(ggplot2)
library(lubridate)
library(forcats)
library(stringr)
library(bslib)
library(scales)
library(DT)

# Get Data ----------------------------------------------------------------

# Load cleaned data (cleaning, categories and real prices are applied during
# data collection - see R/compile_canasta.R)
data <- read_rds("data/CB_FULL.rds")

month_levels <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun",
                  "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")

# Add ym column if not already present
if(!"ym" %in% names(data)) {
  data <- data %>%
    mutate(
      ym = ym(paste0(year, "-", as.numeric(month)))
    )
}

# Base year for real (inflation-adjusted) prices. Real prices are expressed in
# constant cordobas of this year's average price level (see R/ipc.R).
IPC_BASE_YEAR <- 2024
has_estimado  <- any(data$ipc_estimado)

# Calculate last update information
last_data_point <- data %>%
  arrange(desc(year), desc(match(month, month_levels))) %>%
  slice(1)

last_update_text <- paste("Última actualización de datos:",
                          last_data_point$month, last_data_point$year)

# Add app deployment date
app_updated_text <- paste("Aplicación actualizada:", format(Sys.Date(), "%d/%m/%Y"))

# Good choices grouped by official category (renders as optgroups)
good_choices <- data %>%
  distinct(categoria, good) %>%
  arrange(categoria, good)
choices_list <- split(good_choices$good, good_choices$categoria)

# Static summaries (independent of the selected good) ---------------------

# Total canasta cost per month (nominal and real)
grouped_data <- data %>%
  group_by(year, month, ym) %>%
  summarize(
    total      = sum(total, na.rm = TRUE),
    total_real = sum(total_real, na.rm = TRUE),
    .groups    = "drop"
  )

# Cost per category per month (nominal and real)
categoria_data <- data %>%
  group_by(ym, categoria) %>%
  summarize(
    total      = sum(total, na.rm = TRUE),
    total_real = sum(total_real, na.rm = TRUE),
    .groups    = "drop"
  )

# Price-type choices for the selector
price_choices <- c("nominal", "real")
names(price_choices) <- c("Nominal",
                          paste0("Real (córdobas de ", IPC_BASE_YEAR, ")"))

# UI ----------------------------------------------------------------------

# Define UI
ui <- fluidPage(
  theme = bs_theme(
    version = 5, bootswatch = "minty",
    heading_font = font_google("Fira Sans"),
    base_font = font_google("Fira Sans"),
    code_font = font_google("Fira Code")
  ),
  titlePanel(
    "Canasta Básica de Nicaragua"
  ),
  sidebarLayout(
    position = "right",
    fluid = FALSE,
    sidebarPanel(
      radioButtons(
        "priceType",
        "Tipo de precio:",
        choices = price_choices,
        selected = "nominal"
      ),
      selectInput(
        "good",
        "Selecciona un bien de la canasta:",
        choices = choices_list,
        selected = "Queso seco"
      ),
      downloadButton(
        "download1",
        "Descargar la tabla como csv"
      ),
      p(""),
      strong("Aspectos clave de la Canasta Básica:"),
      p(""),
      p("En Nicaragua, la Canasta Básica se compone de tres categorías principales: alimentos, uso doméstico y vestimenta. Se originó en 1988 a raíz de una sugerencia de la Secretaría de Planificación y Presupuesto (SPP) y se basó en datos recopilados en la Encuesta de Ingresos y Gastos de los hogares 1984-85."),
      p("La versión actualizada en 2005 proporciona un total de 2,455 calorías diarias por persona y está diseñada para satisfacer las necesidades energéticas de seis personas con un nivel moderado de actividad física."),
      p("La cobertura de esta canasta está restringida al área urbana de la ciudad de Managua."),
      p(strong("Precios reales: "),
        sprintf("ajustados por inflación a córdobas constantes de %d usando el IPC de Nicaragua (FMI / IFS, base 2010 = 100).", IPC_BASE_YEAR),
        style = "font-size: 12px;"),
      hr(),
      p(strong(last_update_text), style = "color: #2E86AB; font-size: 14px;"),
      p(app_updated_text, style = "color: #666; font-size: 12px;")
    ),
    mainPanel(
      tabsetPanel(
        type = "tabs",
        tabPanel(
          "Por Bien",
          plotOutput("plotBien"),
          DT::DTOutput("tableBien")
        ),
        tabPanel(
          "Por Categoría",
          plotOutput("plotCategoria"),
          DT::DTOutput("tableCategoria")
        ),
        tabPanel(
          "Canasta Agrupada Por Mes",
          plotOutput("plotCanasta"),
          DT::DTOutput("tableCanasta")
        )
      )
    )
  )
)

# Server ------------------------------------------------------------------

# Define server
server <- function(input, output, session) {

  # Which columns / labels to use based on the nominal-vs-real toggle
  price_info <- reactive({
    if (input$priceType == "real") {
      list(
        col    = "precio_real",
        totcol = "total_real",
        ylab   = paste0("Córdobas constantes de ", IPC_BASE_YEAR),
        suffix = paste0(" (reales, córdobas de ", IPC_BASE_YEAR, ")")
      )
    } else {
      list(
        col    = "precio",
        totcol = "total",
        ylab   = "Córdobas (nominales)",
        suffix = " (nominal)"
      )
    }
  })

  # Caption notes the IPC source for real prices and the estimated tail
  plot_caption <- reactive({
    if (input$priceType == "real") {
      base <- "Fuente: INIDE | IPC: FMI/IFS vía DBnomics | Plot: @rrmaximiliano"
      if (has_estimado) base <- paste0(base, "\nÚltimos meses: IPC estimado (último dato oficial extrapolado)")
      base
    } else {
      "Fuente: INIDE | Plot: @rrmaximiliano"
    }
  })

  # Subset the data based on the user's input
  filtered_data <- reactive({
    data %>%
      filter(
        good == input$good
      )
  }) %>%
    bindCache(input$good)

  # Output the plot (Por Bien)
  output$plotBien <- renderPlot({
    info <- price_info()

    title_lab <- sprintf(
      "Precio de %s de %s%s",
      unique(filtered_data()$medida)[1],
      input$good,
      info$suffix
    )

    subtitle_lab <- sprintf(
      "%s - %s",
      min(filtered_data()$year),
      max(filtered_data()$year)
    )

    plot <- filtered_data() %>%
      ggplot(
        aes(
          x = ym,
          y = .data[[info$col]]
        )
      ) +
      geom_line() +
      labs(
        x = "",
        y = info$ylab,
        title = title_lab,
        subtitle = subtitle_lab,
        caption = plot_caption()
      ) +
      scale_y_continuous(labels = comma) +
      theme_minimal(base_size = 14) +
      theme(
        axis.text.x = element_text(size = 16),
        axis.text.y = element_text(size = 16),
        axis.title = element_text(size = 18, face = "bold"),
        plot.title = element_text(size = 20, face = "bold"),
        plot.subtitle = element_text(size = 18),
        plot.caption = element_text(size = 14)
      )

    plot
  })

  # Display the filtered data as a table (Por Bien)
  output$tableBien <- DT::renderDT({
    info <- price_info()
    filtered_data() %>%
      arrange(desc(ym)) %>%
      select(year, month, good, categoria, medida, cantidad,
             precio = all_of(info$col), total = all_of(info$totcol)) %>%
      DT::datatable(
        extensions = 'Buttons',
        options = list(
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel', 'pdf', 'print')
        ),
        rownames = FALSE,
        class = "table-striped"
      ) %>%
      formatRound(columns = c("precio", "total"), digits = 2)
  })

  # Descargar (always exports the full nominal + real detail for the good)
  output$download1 <- downloadHandler(
    filename = function() {
      safe_good <- str_replace_all(input$good, "[^[:alnum:]]+", "_")
      paste0("inide_canasta_basica_", safe_good, "_", Sys.Date(), ".csv")
    },
    content = function(file) {
      write.csv(filtered_data(), file, row.names = FALSE)
    }
  )

  # Output por categoría
  output$plotCategoria <- renderPlot({
    info <- price_info()

    categoria_data %>%
      ggplot(
        aes(
          x = ym,
          y = .data[[info$totcol]],
          color = categoria
        )
      ) +
      geom_line(linewidth = 1) +
      labs(
        x = "",
        y = info$ylab,
        color = "Categoría",
        title = "Costo de la canasta básica por categoría",
        subtitle = names(price_choices)[price_choices == input$priceType],
        caption = plot_caption()
      ) +
      scale_y_continuous(labels = comma) +
      theme_minimal(base_size = 14) +
      theme(
        legend.position = "bottom",
        axis.text = element_text(size = 14),
        axis.title = element_text(size = 16, face = "bold"),
        plot.title = element_text(size = 20, face = "bold"),
        plot.caption = element_text(size = 12)
      )
  })

  # Table por categoría (latest month breakdown)
  output$tableCategoria <- DT::renderDT({
    info <- price_info()
    categoria_data %>%
      arrange(desc(ym), categoria) %>%
      select(ym, categoria, total = all_of(info$totcol)) %>%
      DT::datatable(
        extensions = 'Buttons',
        options = list(
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel', 'pdf', 'print')
        ),
        rownames = FALSE,
        class = "table-striped"
      ) %>%
      formatRound(columns = c("total"), digits = 1)
  })

  # Output por canasta
  output$plotCanasta <- renderPlot({
    info <- price_info()

    grouped_data %>%
      ggplot(
        aes(
          x = ym,
          y = .data[[info$totcol]]
        )
      ) +
      geom_line() +
      labs(
        x = "",
        y = info$ylab,
        title = paste0("Precio total de la canasta básica", info$suffix),
        caption = plot_caption()
      ) +
      scale_y_continuous(labels = comma) +
      theme_minimal(base_size = 14) +
      theme(
        axis.text.x = element_text(size = 16),
        axis.text.y = element_text(size = 16),
        axis.title = element_text(size = 18, face = "bold"),
        plot.title = element_text(size = 20, face = "bold"),
        plot.subtitle = element_text(size = 18),
        plot.caption = element_text(size = 14)
      )
  })

  # Table por canasta
  output$tableCanasta <- DT::renderDT({
    info <- price_info()
    grouped_data %>%
      arrange(desc(ym)) %>%
      select(year, month, total = all_of(info$totcol)) %>%
      DT::datatable(
        extensions = 'Buttons',
        options = list(
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel', 'pdf', 'print')
        ),
        rownames = FALSE,
        class = "table-striped"
      ) %>%
      formatRound(columns = c("total"), digits = 1)
  })
}

# Run the app
shinyApp(ui, server)
