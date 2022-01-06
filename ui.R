library(shiny)

ui <- fluidPage(
  tags$head(
    HTML('<title>CovidSurg - Elective operations real time tracker for England</title>'),
    tags$style(HTML("
                    body {
                    background-color: #cfe2f3;
                    }"))
    ),
  
  span(
    textOutput("dataset_info"),
    style = "color:blue",
    align = 'right'
  ),
  
  HTML(''),
  
  mainPanel(width=8, style='border-style: solid; border-color: black; border-width: 1px; background-color: white; max-width: 850px; margin: 0 auto !important; float: none !important; ',
            h1('Elective operations real time tracker for England'),
            HTML('This tracker estimates the daily reduction in the number of elective (planned) operations in England as a result of the COVID-19 pandemic.<br>These estimates are based on the number of COVID-19 patients in hospital in England each day. Full peer-reviewed methodology is available at <a href="http://www.thelancet.com/journals/lancet/article/PIIS0140-6736(21)02836-1/fulltext">The Lancet.</a>'),
            hr(),
            textOutput('last_date'),
            hr(),
            
            h2('Most recent daily estimates'),
            fluidRow(
              column(width=10, HTML('Percentage reduction in elective surgery volume today compared to what would be expected based on pre-pandemic trends')),
              column(width=2, strong(textOutput('today_perc_reductions')), align='center')
            ),
            hr(),
            fluidRow(
              column(width=10, HTML('Drop in daily total for elective operations performed compared to what would be expected based on pre-pandemic trends')),
              column(width=2, strong(textOutput('today_daily_cancellations')), align='center')
            ),
            hr(),
            
            h2('Running total for estimated reductions in elective surgery'),
            h3('Running total since 1 December 2021'),
            fluidRow(
              column(width=10, HTML('Drop in the number of elective operations performed since 1 December 2021 compared to what would be expected based on pre-pandemic trends')),
              column(width=2, strong(textOutput('running_total_dec_2021')), align='center')
              ),
            
            hr(),
            h3('Running total since 1 March 2020'),
            fluidRow(
              column(width=10, HTML('Drop in the number of elective operations performed since 1 March 2020 compared to what would be expected based on pre-pandemic trends')),
              column(width=2, strong(textOutput('running_total_march_2020')), align='center')
              ),
            
            hr(),
            h2('Reference'),
            HTML('Please reference this data as being based on this article:<br><b><i>COVIDSurg Collaborative. Projecting COVID-19 disruption to elective surgery. Lancet. 2021. Online ahead of print.<br>DOI: https://doi.org/10.1016/S0140-6736(21)02836-1</i></b>'),
            HTML('<br>The article is available online at <a href="http://www.thelancet.com/journals/lancet/article/PIIS0140-6736(21)02836-1/fulltext">The Lancet</a>.'),
            
            hr(),
            HTML('For further information, please <a href="mailto:d.nepogodiev@bham.ac.uk">email us</a>.'),
            HTML('<br> <br>')
  )
)