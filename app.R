
library(shiny)
library(tidyverse)
library(ggplot2)
library(hrbrthemes)
library(bslib)
library(scales)
library(DT)

# Get Data ----------------------------------------------------------------

data <- read_rds("data/CB_FULL.rds") %>% 
  rename(good = bien) %>% 
  mutate(
    month = fct_relevel(
      month, 
      "Ene", "Feb", "Mar", "Abr", "May", "Jun", 
      "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"
    )
  ) %>%
  mutate(
    good = str_squish(good),
    good = case_when(
      str_detect(good, "Brassier") ~ "Brassier/sostén",
      str_detect(good, "Desodorante") ~ "Desodorante nacional",
      str_detect(good, "Pasta dental") ~ "Pasta dental",
      str_detect(good, "Pastas dental") ~ "Pasta dental",
      str_detect(good, "cuero natural") ~ "Zapato de cuero natural",
      TRUE ~ good
    )
  ) %>% 
  mutate(
    ym = paste0(year, "-",as.numeric(month)),
    ym = ym(ym)
  ) %>% 
  group_by(ym) %>% 
  mutate(
    rowid = row_number()
  ) %>% 
  ungroup() %>% 
  mutate(
    good = case_when(
      good == "Calcetines" & rowid == 42 ~ "Calcetines (Hombre)",
      good == "Calcetines" & rowid == 52 ~ "Calcetines (Niños y Niñas)",
      good == "Pantalón largo de tela de jeans" & rowid == 39 ~ "Pantalón largo de tela de jeans (Hombre)",
      good == "Pantalón largo de tela de jeans" & rowid == 45 ~ "Pantalón largo de tela de jeans (Mujeres)",
      TRUE ~ good
    )
  ) %>% 
  mutate(
    medida = str_to_lower(medida),
    precio = case_when(
      is.na(precio) & good == "Alquiler" ~ total, 
      TRUE ~ precio
    )
  )

grouped_data <- data %>% 
  group_by(year, month) %>% 
  summarize(
    sum = sum(total)
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
      p("La cobertura de esta canasta está restringida al área urbana de la ciudad de Managua.")
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
      theme_ipsum_rc() +
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
      theme_ipsum_rc() +
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
