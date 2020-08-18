#' A reference class to represent database connections.
#' @name Database
#' @importFrom methods new
#' @field Driver A character vector such as "ODBC Driver 17 for SQL Server" describing the database driver to use
#' @field Server A character vector representing the hostname of the database
#' @field Schema A character vector representing the schema to create the models table
#' @field Database A character vector representing the SQL Server database name
#' @field UID A character vector such as "myuser" representing the database user to use with SQL Server authentication
#' @field PWD A character vector representing the password of the user to use with SQL Server authentication
#' @field Port An integer representing the database port
Database <- setRefClass("Database",
  fields = c("Driver", "Server", "Schema", "Database", "UID", "PWD", "Port", "Connection"),
  methods = list(
    connect = function() {
      Connection <<- odbc::dbConnect(
        odbc::odbc(),
        Driver = Driver,
        Server = Server,
        Database = Database,
        UID = UID,
        PWD = PWD,
        Port = Port
      )
    },
    disconnect = function() {
      odbc::dbDisconnect(Connection)
    },
    execute = function(statement) {
      statement <- odbc::dbSendStatement(Connection, statement, immediate=T)
      odbc::dbClearResult(statement)
    },
    construct_ddl_statement = function() {
      template = "IF NOT EXISTS (
   SELECT * FROM sys.tables
   AS tb INNER JOIN sys.schemas schemas
   ON tb.schema_id = schemas.schema_id
   WHERE schemas.name = '{{schema}}'
   AND tb.name = 'Models')
CREATE TABLE [{{schema}}].[Models](
  [modelName] [nvarchar](128) NOT NULL,
  [modelSqlTemplate] [nvarchar](max) NOT NULL,
  [dtCreated] [datetime] DEFAULT CURRENT_TIMESTAMP
)"
      whisker::whisker.render(template, list(schema = Schema))
    },
    create_model_table = function() {
      ddl <- construct_ddl_statement()
      execute(ddl)
    },
    construct_model_select = function(auxiliary_columns, model_sql,
                                       response_column, datasource, raw) {
      template <- "SELECT
{{#auxiliary_columns}}
{{.}},
{{/auxiliary_columns}}
{{model_sql}} AS {{response_column}}
FROM {{datasource}}
{{raw}}"
      whisker::whisker.render(template)
    },
    construct_upsert_statement = function() {
      template <- "
  IF NOT EXISTS (SELECT modelName from {{schema}}.Models WHERE modelName = ?)
               INSERT INTO {{schema}}.Models(modelName, modelSqlTemplate)
               VALUES(?, ?)
  ELSE
       UPDATE {{schema}}.Models
       SET modelSqlTemplate = ?
       WHERE modelName = ?"
      whisker::whisker.render(template, list(schema = Schema))
    },
    construct_create_procedure = function() {
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
      whisker::whisker.render(template, list(schema = Schema))
    },
    perform_sproc_exists_check_and_drop = function() {
      template <- "
  IF EXISTS (
      SELECT TYPE_DESC
      FROM sys.procedures WITH(NOLOCK)
      WHERE NAME = 'Predict'
          AND type = 'P'
    )

    DROP PROCEDURE [{{schema}}].[Predict]
  "
      sql <- whisker::whisker.render(template, list(schema = Schema))
      execute(sql)
    },
    create_predict_procedure = function() {
      perform_sproc_exists_check_and_drop()
      create_procedure <- construct_create_procedure()
      execute(create_procedure)
    },
    prepare_statement = function(prepared_statement) {
      odbc::dbSendStatement(Connection, prepared_statement)
    },
    cleanup = function(prepared_statement_object=NA) {
      if (!is.na(prepared_statement_object)) {
        odbc::dbClearResult(prepared_statement_object)
      }
      disconnect()
    },
    bind = function(prepared_statement, datum) {
      odbc::dbBind(prepared_statement, datum)
    },
    initialize = function(db_config_path="db.yml") {
      config <- yaml::yaml.load_file(db_config_path)
      Driver <<- config$Driver
      Server <<- config$Server
      Schema <<- config$Schema
      Database <<- config$Database
      UID <<- config$User
      PWD <<- config$Password
      Port <<- config$Port
      connect()
    }
  )
)
