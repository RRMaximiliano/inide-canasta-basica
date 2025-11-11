
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
library(readr)

# Get Data ----------------------------------------------------------------

# Load cleaned data (cleaning is now applied during data collection)
data <- read_rds("data/CB_FULL.rds")

# Add ym column if not already present
if(!"ym" %in% names(data)) {
  data <- data %>%
    mutate(
      ym = ym(paste0(year, "-", as.numeric(month)))
    )
}

# Calculate last update information
last_data_point <- data %>%
  arrange(desc(year), desc(match(month, c("Ene", "Feb", "Mar", "Abr", "May", "Jun", 
                                          "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")))) %>%
  slice(1)

last_update_text <- paste("Última actualización de datos:", last_data_point$month, last_data_point$year)

# Add app deployment date
app_updated_text <- paste("Aplicación actualizada:", format(Sys.Date(), "%d/%m/%Y"))

grouped_data <- data %>% 
  group_by(year, month) %>% 
  summarize(
    sum = sum(total),
    .groups = "drop"
  ) 

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
      selectInput(
        "good", 
        "Selecciona un bien de la canasta:", 
        choices = sort(unique(data$good)),
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
          dataTableOutput("tableBien")
        ),
        tabPanel(
          "Canasta Agrupada Por Mes",
          plotOutput("plotCanasta"),
          dataTableOutput("tableCanasta")
        )
      )
    )
  )
)

# Server ------------------------------------------------------------------

# Define server
server <- function(input, output, session) {
  # Subset the data based on the user's input
  filtered_data <- reactive({
    data %>%
      filter(
        good == input$good
      ) 
  }) %>% 
    bindCache(input$good)
  
  # Output the plot
  output$plotBien <- renderPlot({
    title_lab <- sprintf(
      "Precio nominal de %s de %s",
      unique(filtered_data()$medida),
      input$good
    )
    
    subtitle_lab <- sprintf(
      "%s - %s",
      min(filtered_data()$year),
      max(filtered_data()$year)
    )
    
    plot <- filtered_data() %>% 
      mutate(
        ym = paste0(year, "-",as.numeric(month)),
        ym = ym(ym)
      ) %>% 
      ggplot(
        aes(
          x = ym,
          y = precio
        )
      ) +
      geom_line() +
      labs(
        x = "",
        y = "Precio en Córdobas",
        title = title_lab,
        subtitle = subtitle_lab,
        caption = "Fuente: INIDE | Plot: @rrmaximiliano"
      ) +
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
  
  # Display the filtered data as a table
  output$tableBien <- renderDataTable({
    filtered_data() %>% 
      arrange(desc(ym)) %>% 
      select(year, month, good, medida, cantidad, precio, total) %>%
      # arrange(year, month) %>% 
      DT::datatable(
        options = list(
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel', 'pdf', 'print')
        ),
        rownames = FALSE, 
        class = "table-striped"
      ) %>% 
      formatRound(columns=c("precio", "total"), digits = 3)
  })
  
  # Descargar
  output$download1 <- downloadHandler(
    filename = function() {
      paste0("inide_canasta_basica_", input$good, "_", Sys.Date(), ".csv")
    },
    content = function(file) {
      write.csv(filtered_data(), file)
    }
  )
  
  
  # Output por canasta
  output$plotCanasta <- renderPlot({
    plot <- grouped_data %>% 
      mutate(
        ym = paste0(year, "-",as.numeric(month)),
        ym = ym(ym)
      ) %>% 
      ggplot(
        aes(
          x = ym,
          y = sum
        )
      ) +
      geom_line() +
      labs(
        x = "",
        y = "Precio en Córdobas",
        title = "Precio nominal total de la canasta básica",
        caption = "Fuente: INIDE | Plot: @rrmaximiliano"
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
  
  # Table por canasta
  output$tableCanasta <- renderDataTable({
    grouped_data %>% 
      mutate(
        ym = paste0(year, "-",as.numeric(month)),
        ym = ym(ym)
      ) %>% 
      arrange(desc(ym)) %>% 
      select(-ym) %>% 
      rename(total = sum) %>% 
      DT::datatable(
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
