library(shiny)

VERSION = 'a0.1'

DF_FILE <- '/rds/homes/r/rothcarv/covidtracker_surgery/20220106_shiny_ready.csv'

server <- function(input, output) {
  df <- read.csv(DF_FILE)
  df$date <- as.Date(df$date, format = "%Y-%m-%d")
  mdate <- max(df$date)
  
  good_stuff <- df[df$date == mdate, ]
  
  
  output$last_date <- renderText(paste0('Data updated on ', good_stuff$formatted))
  output$today_daily_cancellations <- renderText(round(good_stuff$daily_cancellations))
  output$today_perc_reductions <- renderText(paste0(round(good_stuff$percent_op_red*100, digits=2), "%"))
  output$running_total_dec_2021 <- renderText(round(good_stuff$cum_dec))
  output$running_total_march_2020 <- renderText(round(good_stuff$cum_all))
}
