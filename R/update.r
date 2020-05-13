perform_model_update <- function(db, models) {
  model_sql <- list()
  i <- 1
  upsert_sql <- db$construct_upsert_statement()
  prepared_upsert <- db$prepare_statement(upsert_sql)
  for(model in models) {
    cat(paste("    *   Importing ", model$name, " forecast model to SQL Server...\n", sep=""))
    model_object <- readRDS(model$path)
    model_string <- modelc::modelc(model_object)
    model_select <- db$construct_model_select(
      model$auxiliary_columns,
      model_string,
      model$response_column,
      model$datasource,
      model$raw
    )
    record <- c(model$name, model$name, model_select, model_select, model$name)
    db$bind(prepared_upsert, record)
    cat(paste(crayon::green("    ✔"), "   ", model$name, " forecast model deployed!\n", sep=""))
  }
  db$cleanup(prepared_upsert)
}