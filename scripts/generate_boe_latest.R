#!/usr/bin/env Rscript

library(lubridate)
library(jsonlite)
library(BOE)

# Forzar timezone Europe/Madrid
now_madrid <- with_tz(Sys.time(), "Europe/Madrid")
hour_madrid <- hour(now_madrid)

# Salir sin cambios si no es 10, 15 o 20 en Madrid
if (!(hour_madrid %in% c(10, 15, 20))) {
  cat(sprintf("Current hour in Madrid: %02d. Exiting without changes.\n", hour_madrid))
  quit(status = 0)
}

cat(sprintf("Starting BOE Sumario download at %s (Madrid time)\n", 
            format(now_madrid, "%Y-%m-%d %H:%M:%S %Z")))

# Crear directorio si no existe
dir.create("docs/boe", showWarnings = FALSE, recursive = TRUE)

# Timestamp para archivo histórico
timestamp_str <- format(now_madrid, "%Y-%m-%dT%H-%M-%S")
run_file <- sprintf("docs/boe/run_%s.json", timestamp_str)

# Recuperar sumario
result <- tryCatch(
  {
    date_today <- as.Date(now_madrid)
    cat(sprintf("Retrieving sumario for date: %s\n", date_today))
    
    sumario <- BOE::retrieve_sumario(date_today)
    
    if (is.null(sumario) || nrow(sumario) == 0) {
      list(
        meta = list(
          date = as.character(date_today),
          fetched_at_madrid = format(now_madrid, "%Y-%m-%d %H:%M:%S %Z")
        ),
        status = "no_items",
        error = NULL,
        items = list()
      )
    } else {
      # Deduplicación: primero por publication, luego por text+pages
      sumario_dedup <- sumario
      
      if ("publication" %in% names(sumario_dedup)) {
        sumario_dedup <- sumario_dedup[!duplicated(sumario_dedup$publication, fromLast = TRUE), ]
      }
      
      if ("text" %in% names(sumario_dedup) && "pages" %in% names(sumario_dedup)) {
        sumario_dedup <- sumario_dedup[!duplicated(
          paste0(sumario_dedup$text, "|", sumario_dedup$pages), 
          fromLast = TRUE
        ), ]
      }
      
      # Ordenar por section, departament, epigraph
      if ("section" %in% names(sumario_dedup)) {
        sumario_dedup <- sumario_dedup[order(
          sumario_dedup$section,
          if ("departament" %in% names(sumario_dedup)) sumario_dedup$departament else NA,
          if ("epigraph" %in% names(sumario_dedup)) sumario_dedup$epigraph else NA
        ), ]
      }
      
      # Convertir a lista de filas
      items_list <- lapply(seq_len(nrow(sumario_dedup)), function(i) {
        as.list(sumario_dedup[i, ])
      })
      
      list(
        meta = list(
          date = as.character(date_today),
          fetched_at_madrid = format(now_madrid, "%Y-%m-%d %H:%M:%S %Z")
        ),
        status = "ok",
        error = NULL,
        items = items_list
      )
    }
  },
  error = function(e) {
    list(
      meta = list(
        date = as.character(as.Date(now_madrid)),
        fetched_at_madrid = format(now_madrid, "%Y-%m-%d %H:%M:%S %Z")
      ),
      status = "error",
      error = as.character(e),
      items = list()
    )
  }
)

# Guardar latest.json
write_json(result, "docs/boe/latest.json", auto_unbox = TRUE, pretty = TRUE)
cat("Updated: docs/boe/latest.json\n")

# Guardar run_*.json
write_json(result, run_file, auto_unbox = TRUE, pretty = TRUE)
cat(sprintf("Saved: %s\n", run_file))

cat(sprintf("Result status: %s\n", result$status))
quit(status = 0)