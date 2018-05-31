---
title: "Database Bulk Update and Inline Editing in Shiny Application"
author: "Ava Yang"
---

## Motivation

There are times when it costs more than it should to leverage javascript, database, html and all that good stuff in one language. Now maybe is time for connecting some dots, without reaching too hard. 

* If you have been developing shiny apps, consider letting it sit on one live database instead of manipulating data I/O by hand? 
* If you use DT to display tables in shiny apps, care to unleash the power of interactivity to its full?
* If you struggle with constructing SQL queries in R, so did we.    

We created a shiny app demo to show with minimal effort you can have a PostgreSQL database serving a shiny app, and edits from frontend get sent back to database. As seen in the screenshot, after double clicking on a cell and editing value, Save and Cancel buttons will show up. Continue editing, the updates are stored in a temporary (reactiveValue) object. Click on Save if you want to send bulk updates to database; click on Cancel to reset.

<img width="100%" src="./pics/screenshot2.JPG" alt="">

## global

We use `pool` to manage database connections. At the beginning, a database connection pool object is constructed. With the last three lines, the pool object gets closed after a session ends. It massively saves you from worrying about when to open or close a connection. 

```
# Define pool handler by pool on global level
pool <- pool::dbPool(drv = dbDriver("PostgreSQL"),
                     dbname="demo",
                     host="localhost",
                     user= "postgres",
                     password="ava2post")

onStop(function() {
  poolClose(pool)
}) # important!
```

Second we define the function to update database. The glue's `glue_sql` function glues bits and bits of a SQL query in a human readable way. Writing SQL query was bit of a hussule job in R. If you have used `sprintf` or `past` to assemble a SQL clause, you know what I'm talking about. The glued query is then sent to `sqlInterpolate` for SQL injection protection before execution.  

```
updateDB <- function(editedValue, pool, tbl){
  # Keep only the last modification for a cell
  editedValue <- editedValue %>% 
    group_by(row, col) %>% 
    filter(value == dplyr::last(value)| is.na(value)) %>% 
    ungroup()
  
  conn <- poolCheckout(pool)
  
  lapply(seq_len(nrow(editedValue)), function(i){
    id = editedValue$row[i]
    col = dbListFields(pool, tbl)[editedValue$col[i]]
    value = editedValue$value[i]

    query <- glue::glue_sql("UPDATE {`tbl`} SET
                          {`col`} = {value}
                          WHERE id = {id}
                          ", .con = conn)
    
    dbExecute(conn, sqlInterpolate(ANSI(), query))
  })
  
  poolReturn(conn)
  print(editedValue)  
  return(invisible())
}
```


## Server

All the essense is in server.R. 

```
rvs <- reactiveValues(
  data = NA, # most recent data object
  dbdata = NA, # what's in database
  dataSame = TRUE,# logical, whether data has changed from database 
  editedInfo = NA # edited cells altogether
)
```


```
# Generate source via reactive expression
mysource <- reactive({
  pool %>% tbl("nasa") %>% collect()
})

```

```
# Generate source via reactive expression
  mysource <- reactive({
    pool %>% tbl("nasa") %>% collect()
  })
```

```
# Observe the source, update reactive values accordingly
  observeEvent(mysource(), {
    
    # Lightly format data by arranging id
    # Not sure why disordered after sending UPDATE query in db    
    data <- mysource() %>% arrange(id)
    
    rvs$data <- data
    rvs$dbdata <- data
    
  })
```

```
# Render DT table and edit cell
# 
# no curly bracket inside renderDataTable
# selection better be none
# editable must be TRUE
output$mydt <- DT::renderDataTable(
  rvs$data, rownames = FALSE, editable = TRUE, selection = 'none'
)

proxy3 = dataTableProxy('mydt')

observeEvent(input$mydt_cell_edit, {
  
  info = input$mydt_cell_edit
  
  i = info$row
  j = info$col = info$col + 1  # column index offset by 1
  v = info$value
  
  info$value <- as.numeric(info$value)
  
  rvs$data[i, j] <<- DT::coerceValue(v, purrr::flatten_dbl(rvs$data[i, j]))
  replaceData(proxy3, rvs$data, resetPaging = FALSE, rownames = FALSE)
  
  rvs$dataSame <- identical(rvs$data, rvs$dbdata)
  
  if (all(is.na(rvs$editedInfo))) {
    rvs$editedInfo <- data.frame(info)
  } else {
    rvs$editedInfo <- dplyr::bind_rows(rvs$editedInfo, data.frame(info))
  }
})
```

```
# Update edited values in db once save is clicked
observeEvent(input$save, {
  updateDB(editedValue = rvs$editedInfo, pool = pool, tbl = "nasa")
  
  rvs$dbdata <- rvs$data
  rvs$dataSame <- TRUE
})
```

```
# Observe cancel -> revert to last saved version
observeEvent(input$cancel, {
  rvs$data <- rvs$dbdata
  rvs$dataSame <- TRUE
})
```

## UI

The UI part is exactly what you normally do. Nothing new.

## Run the demo app

1. Set up a database instance e.g. PostgreSQL, SQLite, mySQL or MS SQL Server etc.
2. Download/clone the [GitHub repository](https://github.com/MangoTheCat/dtdbshiny) 
3. Run through script `app/prep.R` but change database details to one's own. It writes to DB our demo dataset which is the *nasa* dataset from dplyr with an index column added 
4. Also update database details in `app/app.R` and run
```
shiny::runApp("app")
```

## Acknowledgement 

Workhorse functionality is made possible by 

- DBI: R Database Interface 
- RPostgreSQL: R Interface to PostgreSQL (one of many relational database options)
- pool: DBI connection object pooling
- DT: R Interface to the jQuery Plug-in DataTables
- Shiny: Web Application Framework for R
- dplyr: Data manipulation

This demo is inspired by  

- New inline edit feature of [DT](https://github.com/rstudio/DT/tree/master/inst/examples/DT-edit)(requires version >= 0.2.30)
- [dynshiny](https://github.com/MangoTheCat/dynshiny): Dynamically generated Shiny UI
- Database connectivity struggles like [this](https://github.com/rstudio/pool/issues/58)
- String interpolation with SQL escaping via glue::glue_sql(). The new feature of [glue](https://github.com/tidyverse/glue)(requires version >= 1.2.0) makes construction of query handy and less cumbersome.
- Consultancy projects at Mango
