#' @importFrom whisker whisker.render
#' @title Generate a DDL statement for the models table
#' @param schema A character vector representing the schema under which the table will be created
#' @return A SQL string with a DDL statement
generate_ddl_statement <- function(schema) {
  template = "
IF NOT EXISTS (SELECT * FROM sys.tables AS tb INNER JOIN sys.schemas schemas ON tb.schema_id = schemas.schema_id WHERE schemas.name = '[{{schema}}]' AND tb.name = '[Models]')
CREATE TABLE [{{schema}}].[Models](
	[modelName] [nvarchar](128) NOT NULL,
	[modelSqlTemplate] [nvarchar](max) NOT NULL,
	[dtCreated] [datetime] NOT NULL DEFAULT CURRENT_TIMESTAMP
)
  "
  whisker.render(template, list(schema = schema))
}
