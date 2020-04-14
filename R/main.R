library(odbc)
library(whisker)
source("config.R")

connect <- function() {
  connection <- dbConnect(
    odbc(),
    Driver = config$database_driver,
    Server = config$database_host,
    Database = config$database,
    UID = config$database_user,
    PWD = config$database_password,
    Port = config$database_port
  )
}

execute <- function(statement) {
  connection <- connect()
  dbSendStatement(connection, statement, immediate=T)
  dbDisconnect(connection)
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
  whisker.render(template, list(schema = schema))
}

create_model_table <- function() {
  ddl <- construct_ddl_statement(config$database_schema)
  execute(ddl)
}

construct_model_select <- function(auxiliary_columns, model_sql,
                                   response_column, datasource) {
  template <- "SELECT
{{#auxiliary_columns}}
{{.}},
{{/auxiliary_columns}}
{{model_sql}} AS {{response_column}}
FROM {{datasource}}"
  whisker.render(template)
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
  whisker.render(template, list(schema = schema))
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
  whisker.render(template, list(schema = schema))
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
  sql <- whisker.render(template, list(schema = schema))
  execute(sql)
}

perform_model_update <- function() {
  ddl <- construct_ddl_statement(config$database_schema)
  execute(ddl)
}

construct_model_update <- function() {
  connection <- connect()
  model_sql <- list()
  i <- 1
  upsert_sql <- construct_upsert_statement(config$database_schema)
  prepared_upsert <- dbSendStatement(connection, upsert_sql)
  for(model in models) {
    model_object <- readRDS(model$path)
    model_string <- modelc::modelc(model_object)
    model_select <- construct_model_select(
      model$auxiliary_columns,
      model_string,
      model$response_column,
      model$datasource
    )
    dbBind(prepared_upsert, c(model$name, model$name, model_select, model_select, model$name))
  }
  dbClearResult(prepared_upsert)
  dbDisconnect(connection)
}

construct_test_select <- function(schema) {
  template <- "
EXEC {{schema}}.Predict
    @modelName = ?
  , @dataSourceViewName = ?
;
  "
  whisker.render(template, list(schema = schema))
}

create_predict_procedure <- function() {
  perform_sproc_exists_check_and_drop(config$database_schema)
  create_procedure <- construct_create_procedure(config$database_schema)
  create_procuedre <- sub(create_procedure, "\n", " ")
  execute(create_procedure)
}

test_predict <- function() {
  connection <- connect()
  query <- construct_test_select(config$database_schema)
  prepared_query <- dbSendQuery(connection, query)
  for (model in models) {
    dbBind(prepared_query, c(model$name, model$datasource))
    fetched = dbGetRowsAffected(prepared_query, n = 1)
    cat(paste(model$name, "returns", fetched, "rows"))
  }
  dbClearResult(prepared_query)
  dbDisconnect(connection)
}

main <- function(install = T, update_models = T, validate = F) {
  # Install the model registry table and create the stored procedures
  if (install) {
    create_model_table()
    create_predict_procedure()
  }

  # Perform the model upsert
  if (update_models) {
    perform_model_update()
  }

  # Validate the model queries
  # TODO: This merely prints the number of rows returned by the query,
  # so it needs to be replaced by a better heuristic for validating
  # the models
  if (validate) {
    test_predict()
  }
}
