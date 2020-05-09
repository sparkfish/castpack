config <- list(
  database = "my_database",
  database_schema = "my_schema",
  database_user = "my_user",
  database_password = "my_password",
  database_host = "123.456.10.10",
  database_port = 1433,
  database_driver = "ODBC Driver 17 for SQL Server"
)

models <- list(
  sepal_width_model = list (
    name = "sepal_width_model",
    path = "sepal_width.Rds",
    auxiliary_columns = c(
      "[Sepal.Length]",
      "[Petal.Width]"
    ),
    response_column = "[Sepal.Width]",
    datasource = "iris"
  ),
  another_model = list (
    name = "mymodelname",
    path = "modelfile.Rds",
    auxiliary_columns = c(
        "some",
        "additional",
        "insightful",
        "columns"
    ),
    response_column = "winning_sequence",
    datasource = "lottery_numbers"
  )
)
