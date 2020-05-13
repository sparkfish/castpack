#source("config.R")
options(scipen=999)

connect <- function() {
  connection <- odbc::dbConnect(
    odbc::odbc(),
    Driver = config$database_driver,
    Server = config$database_host,
    Database = config$database,
    UID = config$database_user,
    PWD = config$database_password,
    Port = config$database_port
  )
}

execute <- function(statement) {
  connection <- odbc::connect()
  odbc::dbSendStatement(connection, statement, immediate=T)
  odbc::dbDisconnect(connection)
}

construct_ddl_statement <- function(schema) {
  template = "
IF NOT EXISTS (SELECT * FROM sys.tables AS tb INNER JOIN sys.schemas schemas ON tb.schema_id = schemas.schema_id WHERE schemas.name = '{{schema}}' AND tb.name = 'Models')
CREATE TABLE [{{schema}}].[Models](
	[modelName] [nvarchar](128) NOT NULL,
	[modelSqlTemplate] [nvarchar](max) NOT NULL,
	[dtCreated] [datetime] DEFAULT CURRENT_TIMESTAMP
)
  "
 whisker::whisker.render(template, list(schema = schema))
}

create_model_table <- function() {
  ddl <- construct_ddl_statement(config$database_schema)
  execute(ddl)
}

construct_model_select <- function(auxiliary_columns, model_sql,
                                   response_column, datasource, raw) {
  template <- "SELECT
{{#auxiliary_columns}}
{{.}},
{{/auxiliary_columns}}
{{model_sql}} AS {{response_column}}
FROM {{datasource}}
{{raw}}"
  whisker::whisker.render(template)
}

construct_upsert_statement <- function(schema) {
  template <- "
  IF NOT EXISTS (SELECT modelName from {{schema}}.Models WHERE modelName = ?)
               INSERT INTO {{schema}}.Models(modelName, modelSqlTemplate)
               VALUES(?, ?)
  ELSE
       UPDATE {{schema}}.Models
       SET modelSqlTemplate = ?
       WHERE modelName = ?"
  whisker::whisker.render(template, list(schema = schema))
}

construct_create_procedure <- function(schema) {
  template <- "
CREATE PROCEDURE [{{schema}}].[Predict]
(
@modelName NVARCHAR(128),
@dataSourceViewName NVARCHAR(258)
)
AS

DECLARE @modelSqlTemplate NVARCHAR(MAX) = (SELECT modelSqlTemplate FROM {{schema}}.Models WHERE modelName = @modelName )

IF @modelSqlTemplate IS NULL
BEGIN
	RAISERROR('There is no model named ''%s'' in {{schema}}.Models model registry table.', 16, 1, @modelName ) WITH NOWAIT
	RETURN;
END

DECLARE @dynSqlToExec NVARCHAR(MAX) = REPLACE( @modelSqlTemplate, '$(sourceViewName)', @dataSourceViewName )

PRINT @dynSqlToExec

EXEC( @dynSqlToExec )

"
  whisker::whisker.render(template, list(schema = schema))
}

perform_sproc_exists_check_and_drop <- function(schema) {
  template <- "
  IF EXISTS (
      SELECT TYPE_DESC
      FROM sys.procedures WITH(NOLOCK)
      WHERE NAME = 'Predict'
          AND type = 'P'
    )

    DROP PROCEDURE [{{schema}}].[Predict]
  "
  sql <- whisker::whisker.render(template, list(schema = schema))
  execute(sql)
}

perform_model_update <- function() {
  connection <- connect()
  model_sql <- list()
  i <- 1
  upsert_sql <- construct_upsert_statement(config$database_schema)
  prepared_upsert <- odbc::dbSendStatement(connection, upsert_sql)
  for(model in models) {
    cat(paste("    *   Importing ", model$name, " forecast model to SQL Server...\n", sep=""))
    model_object <- readRDS(model$path)
    model_string <- modelc::modelc(model_object)
    model_select <- construct_model_select(
      model$auxiliary_columns,
      model_string,
      model$response_column,
      model$datasource,
      model$raw
    )
    odbc::dbBind(prepared_upsert, c(model$name, model$name, model_select, model_select, model$name))
    cat(paste(crayon::green("    ✔"), "   ", model$name, " forecast model deployed!\n", sep=""))
    #dbClearResult(prepared_upsert)
  }
  odbc::dbClearResult(prepared_upsert)
  odbc::dbDisconnect(connection)
}

construct_test_select <- function(schema) {
  template <- "
EXEC {{schema}}.Predict
    @modelName = ?
  , @dataSourceViewName = ?
;
  "
  whisker::whisker.render(template, list(schema = schema))
}

create_predict_procedure <- function() {
  perform_sproc_exists_check_and_drop(config$database_schema)
  create_procedure <- construct_create_procedure(config$database_schema)
  #create_procedure <- sub(create_procedure, "\n", " ")
  execute(create_procedure)
}

test_predict <- function() {
  connection <- connect()
  query <- construct_test_select(config$database_schema)
  prepared_query <- odbc::dbSendQuery(connection, query)
  for (model in models) {
    odbc::dbBind(prepared_query, c(model$name, model$datasource))
    fetched = odbc::dbGetRowsAffected(prepared_query, n = 1)
    cat(paste(model$name, "returns", fetched, "rows"))
  }
  odbc::dbClearResult(prepared_query)
  odbc::dbDisconnect(connection)
}

print_header  <- function() {
  # TODO: Inject version from the environment 
  cat(paste(crayon::yellow("✨"), "Castpack v0.5, 2020.10.09\n"))
  cat("----------------------------\n")
}

read_config <- function(path="config.R") {
    source(path)
}

prepare_registry <- function() {
  # Create the necessary objects to deploy models and query predictions
  print_header()
  cat("- Preparing model registry for Castpack\n")
  cat(paste("    ", "*",  " Creating SQL Server model registry table\n", sep=""))
  create_model_table()
  cat(paste("    ", crayon::green("✔"), " Model registry table created!\n", sep=""))
  cat(paste("    ", "*",  " Creating SQL Server Predict procedure\n", sep=""))
  create_predict_procedure()
  cat(paste("    ", crayon::green("✔"), " Predict procedure created!\n", sep=""))
  cat(paste(crayon::yellow("👍"), " Success! Model registry and Predict procedure initialized.\n"))
  cat("You are now ready to begin using Castpack to import models into your database\n")
  cat("To import an R forecast model, save it to the current working directory as an .Rds file and configure it in config.R\n")
}

deploy_models <- function(validate = F) {
   # Perform the model upsert 
  read_config()
  print_header()
  discover_models()
  perform_model_update()
  cat(paste(crayon::yellow("👍"), "   Success! All forecast models were successfully deployed to SQL Server.\n"))
   # Validate the model queries
  # TODO: This merely prints the number of rows returned by the query,
  # so it needs to be replaced by a better heuristic for validating
  # the models
  if (validate) {
    test_predict()
  }
}

discover_models <- function(){
  # Discover models present for manifest output
  found_models <- c()
  for (model in models) {
    found_models <- c(found_models, model$name)
  }
  found_models_string <- paste(found_models, collapse=", ")
  found_ <- paste("-   Found the following forecast models:", found_models_string, "\n")
  cat(found_)
}
