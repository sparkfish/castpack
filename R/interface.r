print_header  <- function() {
  # TODO: Inject version from the environment
  cat(paste(crayon::yellow("✨"), "Castpack v0.5, 2020.10.09\n"))
  cat("----------------------------\n")
}

prepare_registry <- function(db_config_path="db.yml") {
  # Create the necessary objects to deploy models and query predictions
  print_header()
  db <- Database$new(db_config_path)
  cat("- Preparing model registry for Castpack\n")
  cat(paste("    ", "*",  " Creating SQL Server model registry table\n", sep=""))
  db$create_model_table()
  cat(paste("    ", crayon::green("✔"), " Model registry table created!\n", sep=""))
  cat(paste("    ", "*",  " Creating SQL Server Predict procedure\n", sep=""))
  db$create_predict_procedure()
  cat(paste("    ", crayon::green("✔"), " Predict procedure created!\n", sep=""))
  cat(paste(crayon::yellow("👍"), " Success! Model registry and Predict procedure initialized.\n"))
  db$cleanup()
  cat("You are now ready to begin using Castpack to import models into your database\n")
  cat("To import an R forecast model, save it to the current working directory as an .Rds file and configure it in config.R\n")
}

deploy_models <- function(model_config_path = "models.yml", db_config_path = "db.yml", validate = F) {
  # Perform the model upsert
  models <- read_config("models.yml")
  db <- Database$new(db_config_path)

  print_header()
  print_manifest(models)

  perform_model_update(db, models)
  cat(paste(crayon::yellow("👍"), "   Success! All forecast models were successfully deployed to SQL Server.\n"))

  # Validate the model queries
  # TODO: This merely prints the number of rows returned by the query,
  # so it needs to be replaced by a better heuristic for validating
  # the models
  if (validate) {
    test_predict()
  }
}

print_manifest <- function(models) {
  # Discover models present for manifest output
  found_models <- c()
  for (model in models) {
    found_models <- c(found_models, model$name)
  }
  found_models_string <- paste(found_models, collapse=", ")
  found_ <- paste("-   Found the following forecast models:", found_models_string, "\n")
  cat(found_)
}

