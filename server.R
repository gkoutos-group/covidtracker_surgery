library(shiny)
library(lubridate)

VERSION = 'a0.2'

############ defines
SHINY_READY <- '20220106_shiny_ready.csv'
REFERENCE_FILE <- 'electiveactivity_5jan22.csv'
HOLIDAYS_FILE = '20220106_holidays_processed.csv'
YEAR_RANGE = c(2021, 2022)
FORMULA <- function(H__n_of_hospitalCases) {
  return(0.8411886 *  (0.98515 ** (H__n_of_hospitalCases / 1000)))
}
PAGE <- "https://api.coronavirus.data.gov.uk/v2/data?areaType=nation&areaCode=E92000001&metric=hospitalCases&format=json"
PATH_UPDATE_CONTROL <- 'day_check/' # folder for stopping multiple daily checks for new data
############

dprint <- function(e) {
  if(F) {
    print(e)
  }
}

assert <- function(cond, message) {
  if(!cond) {
    error(message)
  }
}

# folder for update control
dir.create(file.path(PATH_UPDATE_CONTROL), showWarnings = FALSE)
was_today_evaluated <- function(d) {
  d <- format(d, '%Y-%m-%d')
  
  day_file <- file.path(PATH_UPDATE_CONTROL, d)
  if(!file.exists(day_file)) {
    return(F)
  } else {
    return(T)
  }
}

set_today_evaluated <- function(d) {
  d <- format(d, '%Y-%m-%d')
  
  day_file <- file.path(PATH_UPDATE_CONTROL, d)
  
  x <- data.frame()
  write.table(x, file=day_file, col.names=FALSE)
}



# holidays
dfholidays <- read.csv(HOLIDAYS_FILE)

is_working_day <- function(d) {
  if((as.POSIXlt(d)$wday > 0) & (as.POSIXlt(d)$wday < 6)) {
    return(T)
  }
  return(F)
}

is_holiday <- function(d) {
  return(format(d, "%Y-%m-%d") %in% dfholidays$date)
}

download_data <- function() {
  # main data
  df <- read.csv(REFERENCE_FILE, fileEncoding="UTF-8-BOM")
  df <- df[!is.na(df$Month),]
  df$last_date <- as.Date(df$Month, format="%d/%m/%Y")
  df$year <- as.numeric(format(df$last_date, format="%Y"))
  df$month <- as.numeric(format(df$last_date, format="%m"))
  
  # gov df
  r <- httr::GET(PAGE)
  r_content <- httr::content(r, type="application/json", encoding = "ISO-8859-1")
  dfgov <- dplyr::bind_rows(r_content)
  assert(nrow(dfgov) > 1, "No data collected from UK gov!")
  
  dfgov$date = as.Date(dfgov$date, format="%Y-%m-%d")
  
  get_year_month_working_days <- function() {
    # get number of working days per month
    year <- vector()
    month <- vector()
    working_days <- vector()
    
    holidays_processed <- 0
    
    for(y in seq(YEAR_RANGE[1], YEAR_RANGE[2])) {
      for(m in seq(1: 12)) {
        e <- as.integer(lubridate::days_in_month(lubridate::ymd(paste(y, m, '01', sep="-"))))
        
        wd <- 0 # number of working days
        
        for(d in seq(lubridate::ymd(paste(y, m, '01', sep="-")), 
                     lubridate::ymd(paste(y, m, e, sep="-")),
                     "days")) {
          d <- as.Date(d, origin='1970-01-01')
          if(is_working_day(d)) {
            if(is_holiday(d)) {
              holidays_processed <- holidays_processed + 1
            } else {
              wd <- wd + 1
            }
          }
        }
        
        year <- append(year, y)
        month <- append(month, m)
        working_days <- append(working_days, wd)
      }
    }
    
    assert(holidays_processed == nrow(dfholidays), "There were issues calculating the number of working days in the month, probably code error")
    return(data.frame(year, month, working_days))
  }
  
  dfworking_days <- get_year_month_working_days()
  
  df <- merge(df, 
              dfworking_days,
              by=c('year', 'month'),
              all.x=T,
              all.y=F)
  
  df$daily_expected <- df$Expected.volume/df$working_days
  # intermediary calculations are here
  
  max_surgery <- max(df$last_date)
  max_govdata <- max(dfgov$date)
  
  get_cum_cases <- function() {
    cum_all_calc <- round(sum(df$Drop.from.expected.volume))
    cum_from_december_first <- round(sum(df[df$last_date >= ymd('2021-12-1'), ]$Drop.from.expected.volume))
    
    year <- vector()
    month <- vector()
    day <- vector()
    hosp_days <- vector()
    expected_surg_day <- vector()
    percent_op <- vector()
    percent_op_red <- vector()
    daily_cancellations <- vector()
    cum_all <- vector()
    cum_dec <- vector()
    
    for(d in seq(max_surgery + 1,
                 max_govdata,
                 "days")) {
      d <- as.Date(d, origin='1970-01-01')
      if(is_working_day(d)) {
        if(is_holiday(d)) {
          next
        } else {
          # get hospitalisation data from gov file
          assert(nrow(dfgov[dfgov$date == d, ]) == 1, "Number of coronadata not equal to 1")
          hospitalisations_day <- dfgov[dfgov$date == d, ]$hospitalCases
          
          # expected surgery number daily uses the estimate from previous year!!
          assert(nrow(df[(df$month == lubridate::month(d)) & (df$year == lubridate::year(d) - 1), ]) == 1, "Number of daily surgeries not equal to 1")
          expected_surgery_day <- df[(df$month == lubridate::month(d)) & (df$year == lubridate::year(d) - 1), ]$daily_expected
          
          # calculate other needed data
          percent_operations <- FORMULA(hospitalisations_day)
          percent_reduction_operations <- 1 - percent_operations
          daily_rate_cancelations <- round(percent_reduction_operations * expected_surgery_day)
          
          cum_all_calc <- cum_all_calc + daily_rate_cancelations
          cum_from_december_first <- cum_from_december_first + daily_rate_cancelations
          
          year <- append(year, lubridate::year(d))
          month <- append(month, lubridate::month(d))
          day <- append(day, lubridate::day(d))
          hosp_days <- append(hosp_days, hospitalisations_day)
          expected_surg_day <- append(expected_surg_day, expected_surgery_day)
          percent_op <- append(percent_op, percent_operations)
          percent_op_red <- append(percent_op_red, percent_reduction_operations)
          daily_cancellations <- append(daily_cancellations, daily_rate_cancelations)
          cum_all <- append(cum_all, cum_all_calc)
          cum_dec <- append(cum_dec, cum_from_december_first)
        }
      }
    }
    return(data.frame(year, month, day, hosp_days, expected_surg_day, percent_op, percent_op_red, daily_cancellations, cum_all, cum_dec))
  }
  
  complete_data <- get_cum_cases()
  
  complete_data$date = paste(complete_data$year, complete_data$month, complete_data$day, sep='-')
  complete_data$date = lubridate::ymd(complete_data$date)
  complete_data$formatted = format(complete_data$date, '%A, %d %B %Y')
  
  write.csv(complete_data, 
            file=SHINY_READY,
            row.names=FALSE)
  return(complete_data)
}

from_shiny_ready <- function() {
  df <- read.csv(SHINY_READY)
  df$date <- as.Date(df$date, format = "%Y-%m-%d")
  return(df)
}

get_shiny_data <- function() {
  # if no data exists download it
  if(!file.exists(SHINY_READY)) {
    dprint('Downloaded')
    return(download_data())
  }
  
  # if data exists:
  df <- from_shiny_ready()
  tday <- lubridate::today()
  if(tday == max(df$date)) { # if data is from today
    dprint('From CSV')
    return(df)
  } else {
    # check if any working day between data and today
    wd <- 0
    for(d in seq(max(df$date) + 1,
                 tday,
                 "days")) {
      d <- as.Date(d, origin='1970-01-01')
      if(!is_holiday(d) & is_working_day(d)) {
        wd <- wd + 1
      }
    }
    if(was_today_evaluated(tday) | (wd == 0) | ((wd == 1) & (hour(lubridate::now()) < 16))) {
      dprint('From CSV')
      return(df)
    } else {
      dprint('Downloaded')
      set_today_evaluated(tday)
      return(download_data())
    }
  }
}

server <- function(input, output) {
  df <- get_shiny_data()
  mdate <- max(df$date)
  
  good_stuff <- df[df$date == mdate, ]
  
  output$last_date <- renderText(paste0('Data updated on ', good_stuff$formatted))
  output$today_daily_cancellations <- renderText(round(good_stuff$daily_cancellations))
  output$today_perc_reductions <- renderText(paste0(round(good_stuff$percent_op_red*100, digits=1), "%"))
  output$running_total_dec_2021 <- renderText(round(good_stuff$cum_dec))
  output$running_total_march_2020 <- renderText(round(good_stuff$cum_all))
}
