#' @title Print a header with the program name and version information
#' @importFrom utils packageVersion
print_header  <- function() {
  cat(paste(crayon::yellow("\u2728"), "Castpack", packageVersion("Castpack"), "\n"))
  cat("------------\n")
}


#' @title Prepare a SQL Server Database for Model Uploads
#' @param db_config_path A character vector representing the path to a YAML file with database configuration details
#' @export
#' @examples
#' # Ensure that a db.yml file is in the current working directory with the following
#' # keys filled out at the top level
#' #
#' # Database: "MyDatabase"                   # The SQL Server database name where the models will be stored
#' # Schema: "some_schema"                    # The (unbracketed) SQL Server database schema that the model registry will be written to
#' # User: "my_db_user"                       # The username that will be used for SQL Server authentication
#' # Password: "password123"                  # The password that will be used for SQL Server authentication
#' # Server: "my.database.hostname"           # The hostname of the database server
#' # Port: 1433                               # An integer representing the port number of the database
#' # Driver: "ODBC Driver 17 for SQL Server"  # A string representing the driver to be used to interact with SQL Server
#'
#' # Prepare the registry
#' prepare_registry()
prepare_registry <- function(db_config_path="db.yml") {
  # Create the necessary objects to deploy models and query predictions
  print_header()
  db <- Database$new(db_config_path)
  cat("- Preparing model registry for Castpack\n")
  cat(paste("    ", "*",  " Creating SQL Server model registry table\n", sep=""))
  db$create_model_table()
  cat(paste("    ", crayon::green("\u2714"), " Model registry table created!\n", sep=""))
  cat(paste("    ", "*",  " Creating SQL Server Predict procedure\n", sep=""))
  db$create_predict_procedure()
  cat(paste("    ", crayon::green("\u2714"), " Predict procedure created!\n", sep=""))
  cat(paste(crayon::yellow("\u1f44d"), " Success! Model registry and Predict procedure initialized.\n"))
  db$cleanup()
  cat("You are now ready to begin using Castpack to import models into your database\n")
  cat("To import an R forecast model, save it to the current working directory as an .Rds file and configure it in config.R\n")
}

#' @title Deploy models to SQL Server
#' @param db_config_path A character vector representing the path to a YAML file with database configuration details
#' @param model_config_path A character vector representing the path to a YAML file with model configuration details
#' @examples
#' a <- 1:10
#' b <- 2*1:10
#' c <- as.factor(a)
#' df <- data.frame(a, b, c)
#' formula = b ~ a + c
#' linear_model <- lm(formula, data = df)
#' saveRDS(linear_model, file="my_model.Rds")
#'
#' # Now that the model is saved to disk, add the following
#' # record to models.yml, assuming that db_config
#'
#' # mymodel:
#' #   name: "my_model"
#' #   path: "/path/to/my_model.Rds"
#' #   auxiliary_columns: ["INTERESTING_COLUMN"]
#' #   response_column: "b"
#' #   raw: "ORDER BY a, c ASC"
#' #   datasource: "[some_schema].[my_abcs]"
#'
#' # In case we haven't yet prepared the model registry in our database
#' prepare_registry()
#' deploy_models()
#' @export
deploy_models <- function(model_config_path = "models.yml", db_config_path = "db.yml") {
  # Perform the model upsert
  models <- read_config("models.yml")
  db <- Database$new(db_config_path)

  print_header()
  print_manifest(models)

  perform_model_update(db, models)
  cat(paste(crayon::yellow("\u1f44d"), "   Success! All forecast models were successfully deployed to SQL Server.\n"))

}

#' @title Print details about models to be deployed
#' @param models A vector of \code{lm} or \code{glm} model objects
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

