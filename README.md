# Castpack ✨

Castpack is a magical R library that lets you effortlessly import linear models into your Microsoft SQL Server database.

Leveraging the powerful open-source [modelc](https://github.com/team-sparkfish/modelc) library, Castpack will transpile models consisting of hundreds of parameters to performant ANSI SQL in mere seconds, and load them into your database in the blink of an eye. Just bring your models as `.rds` files, tell Castpack about your database with a simple configuration file, and let her rip!

Unlike other libraries and tools, Castpack was purpose-built for predictive linear and generalized linear models. This focus on linear models keeps Castpack lightweight, and allows it to support linear models and GLMs that other libraries choke on.

It was inspired by and builds upon the venerable [tidypredict](https://tidymodels.github.io/tidypredict/) library.

## Installation

Using `devtools`:

```{R}
install.packages("devtools")
install.packages("remotes")
remotes::install_github("team-sparkfish/Castpack")
```
Prepare a `config.r` file:

```{R}
config <- list(
  database = "my_database_name",
  database_schema = "my_schema",
  database_user = "my_user",
  database_password = "my_password",
  database_host = "123.456.10.10",
  database_port = 1433,
  # This must be an ODBC SQL Server driver
  database_driver = "ODBC Driver 17 for SQL Server"
)

models <- list()
```
Set your working directory to your `config.r` path, and do

```{R}
castpack::install()
```

This will create the necessary objects for models to be loaded and run inside your database.

## How it works

Castpack is simple to use because it is opinionated (in a "convention over configuration" sense) about how models are represented in your database.

When you run `castpack::install()`, Castpack creates two objects: a `${schema}.Models` table (where `${schema}` is the schema you specified in your configuration file), along with `${schema}.Predict`, a stored procedure for running predictions inside the database.

The `Predict` procedure takes as arguments a model name and a datasource name. The latter must correspond to an existing view or table.

The models specified in `config.r` are then transpiled from `.rds` format files into ANSI SQL queries, which are upserted into the `Models` table. From there, you can run the `Predict` procedure against the model and a table or view in your database.

Because the models are nothing more than formulas represented as select statements, they are blazing fast.

## API

- `castpack::install()` creates the `${schema}.Models` table and `${schema}.Predict` procedure
- `castpack::main()` upserts the models specified in `config.r` to the `Models` table. This function depends on a `models` variable defined in `config.r` that tells Castpack about the models you'd like to load into your database. See `example.config.r` for an example configuration. 
