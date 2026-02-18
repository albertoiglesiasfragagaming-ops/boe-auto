#!/usr/bin/env Rscript

# Load required libraries
library(BOE)
library(jsonlite)
library(lubridate)

# Set timezone to Europe/Madrid
Sys.setenv(TZ = "Europe/Madrid")

# Get current time in Madrid timezone
now_madrid <- with_tz(Sys.time(), "Europe/Madrid")
hour_madrid <- hour(now_madrid)
date_madrid <- as.Date(now_madrid)

# Check if current hour is 10, 15, or 20 in Madrid time
if (!(hour_madrid %in% c(10, 15, 20))) {
  message(sprintf("Current hour in Madrid: %d. Not an execution hour (10, 15, 20). Exiting without changes.", hour_madrid))
  quit(status = 0)
}

message(sprintf("Executing BOE sumario download at %s Madrid time", format(now_madrid, "%Y-%m-%d %H:%M:%S")))

# Create output directory if it doesn't exist
dir.create("docs/boe", showWarnings = FALSE, recursive = TRUE)

# Timestamp for run file
timestamp_iso <- format(now_madrid, "%Y-%m-%dT%H-%M-%S")
run_file <- sprintf("docs/boe/run_%s.json", timestamp_iso)

# Initialize result structure
result <- list(
  meta = list(
    date = format(date_madrid, "%Y-%m-%d"),
    fetched_at_madrid = format(now_madrid, "%Y-%m-%d %H:%M:%S %Z")
  ),
  status = "ok",
  error = NULL,
  items = list()
)

# Try to retrieve BOE sumario
tryCatch(
  {
    message(sprintf("Retrieving BOE sumario for %s", format(date_madrid, "%Y-%m-%d")))
    
    # Call retrieve_sumario from BOE package
    sumario_data <- BOE::retrieve_sumario(date_madrid)
    
    # Check if we got data
    if (is.null(sumario_data) || nrow(sumario_data) == 0) {
      result$status <- "no_items"
      message("No BOE items found for this date")
    } else {
      message(sprintf("Retrieved %d items from BOE", nrow(sumario_data)))
      
      # Deduplication: remove duplicates by publication, or by (text + pages) if no publication
      if ("publication" %in% names(sumario_data)) {
        sumario_data <- sumario_data[!duplicated(sumario_data$publication, fromLast = TRUE), ]
      } else if ("text" %in% names(sumario_data) && "pages" %in% names(sumario_data)) {
        sumario_data <- sumario_data[!duplicated(paste(sumario_data$text, sumario_data$pages), fromLast = TRUE), ]
      }
      
      # Sort by section, departament, epigraph for consistency
      sort_cols <- c()
      if ("section" %in% names(sumario_data)) sort_cols <- c(sort_cols, "section")
      if ("departament" %in% names(sumario_data)) sort_cols <- c(sort_cols, "departament")
      if ("epigraph" %in% names(sumario_data)) sort_cols <- c(sort_cols, "epigraph")
      
      if (length(sort_cols) > 0) {
        sumario_data <- sumario_data[do.call(order, as.list(sumario_data[, sort_cols])), ]
      }
      
      # Convert to list of records
      result$items <- lapply(1:nrow(sumario_data), function(i) {
        as.list(sumario_data[i, ])
      })
      
      result$status <- "ok"
      message(sprintf("Successfully processed %d items", length(result$items)))
    }
  },
  error = function(e) {
    result$status <<- "error"
    result$error <<- as.character(e)
    message(sprintf("Error retrieving BOE sumario: %s", as.character(e)))
  }
)

# Write latest.json
write_json(result, "docs/boe/latest.json", auto_unbox = TRUE, pretty = TRUE)
message("Written docs/boe/latest.json")

# Write run_TIMESTAMP.json for audit trail
write_json(result, run_file, auto_unbox = TRUE, pretty = TRUE)
message(sprintf("Written %s", run_file))

message("BOE sumario download completed successfully")
