# Packages ----------------------------------------------------------------

library(bs4Dash)
library(DT)
library(tidyverse)
library(hrbrthemes)
library(shinyWidgets)
library(stringr)
library(shinydashboardPlus)

# Get data ----------------------------------------------------------------

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
  ) 

# ui ----------------------------------------------------------------------

ui <- dashboardPage(
  skin = "green",
  dashboardHeader(title = "Canasta Básica de Nicaragua", titleWidth = 400),
  dashboardSidebar(
    width = 400,
    selectInput(
      "good", 
      "Choose a good:",
      choices = sort(unique(data$good)),
      selected = "Queso seco"
    )
  ),
  dashboardBody(
    fluidRow(
      plotOutput("plotBien"),
      dataTableOutput("tableBien")
    )
  )
)

# server ------------------------------------------------------------------

server <- function(input, output) {
  
  # Subset the data based on the user's input
  filtered_data <- reactive({
    data %>%
      filter(
        good == input$good
      ) 
  })
  
  # Output the plot
  output$plotBien <- renderPlot({
    title_lab <- sprintf(
      "Precio nominal de %s de %s según la canasta básica de Nicaragua",
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
  
  # Output the table
  output$tableBien <- DT::renderDataTable({
    filtered_data() %>%
      select(year, month, good, medida, cantidad, precio, total) %>%
      arrange(year, month) %>% 
      DT::datatable(
        options = list(
          dom = 'Bfrtip',
          buttons = c('copy', 'csv', 'excel', 'pdf', 'print')
        ),
        class = "table-striped"
      )
  })
}


# Run app -----------------------------------------------------------------

shinyApp(ui = ui, server = server)

