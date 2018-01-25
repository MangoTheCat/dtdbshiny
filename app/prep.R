# Write source dataset to DB
#
#----------------------------------------
# Load libraries
library(DBI)
library(RPostgreSQL)
library(dplyr)

#----------------------------------------
# Write dplyr::nasa dataset to PostgreSQL
con <- DBI::dbConnect(drv = dbDriver("PostgreSQL"),
                      dbname="demo",
                      host="localhost",
                      user= "postgres",
                      password="ava2post")

nasa <- as.data.frame(nasa) %>% 
  mutate(id = 1:n()) %>% 
  select(id, everything())

DBI::dbWriteTable(con, "nasa", nasa, overwrite = TRUE, row.names = FALSE)

#----------------------------------------
# Read from DB just to check
#nasa1 <- dbReadTable(con, "nasa", check.names = FALSE)

dbDisconnect(con)
