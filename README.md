<p align="center"><img width="640" src="https://user-images.githubusercontent.com/1108065/82249535-90bbb000-990f-11ea-9183-d24870f828af.png" alt="Castpack logo"></p>

Castpack is a magical R library that lets you effortlessly package linear forecast models and deploys them for use directly in your Microsoft SQL Server database.

Leveraging the powerful open-source [modelc](https://github.com/team-sparkfish/modelc) library, Castpack will transpile models consisting of hundreds of parameters to performant ANSI SQL in mere seconds, and load them into your database in the blink of an eye. Just bring your models as `.rds` files, tell Castpack about your database with a simple configuration file, and let her rip!

Unlike other libraries and tools, Castpack was purpose-built for predictive linear and generalized linear models. This focus on linear models keeps Castpack lightweight, and allows it to support linear models and GLMs that other libraries choke on.

It was inspired by and builds upon the venerable [tidypredict](https://tidymodels.github.io/tidypredict/) library.

## Installation

Using `devtools`:

```{R}
install.packages("devtools")
install.packages("remotes")
remotes::install_github("team-sparkfish/Castpack", dependencies=T)
```

Prepare a workspace directory:

```{shell}
$ mkdir workspace
```

Copy the `example.models.yml` and `example.db.yml` configuration files to `workspace/models.yml` and `workspace/db.yml` respectively and fill in the details for your database and model.

Set your R working directory to your workspace, and run

```{R}
Castpack::prepare_registry()
```

This will create the necessary objects for models to be loaded and run inside your database.

## How it works

Castpack is simple to use because it is opinionated (in a "convention over configuration" sense) about how models are represented in your database.

When you run `Castpack::prepare_registry()`, Castpack creates two objects: a `${schema}.Models` table (where `${schema}` is the schema you specified in your configuration file), along with `${schema}.Predict`, a stored procedure for running predictions inside the database.

The `Predict` procedure takes as arguments a model name and a datasource name. The latter must correspond to an existing view or table.

The models specified in `models.yml` are then transpiled from `.rds` format files into ANSI SQL queries, which are upserted into the `Models` table. From there, you can run the `Predict` procedure against the model and a table or view in your database.

Because the models are nothing more than formulas represented as select statements, they are blazing fast.

## Making Predictions

To make predictions, used the `Predict` function that is created when `Castpack::prepare_registry()` is run.

It takes two arguments:

``` sql
@modelName NVARCHAR(128),
@dataSourceViewName NVARCHAR(258)
```

`@dataSourceViewName` should be the name of an existing table or view.

## Model Configuration

Use `models.yml` to configure your models. There should be a toplevel key for each model to be imported consisting of the following attributes

- `name` The model name is used by the `Predict` procedure to apply the model against the specified dataset
- `path` The path to the model file. The model should live on disk as a `.Rds` formatted file
- `datasource` The data source should be an existing table or view the model should be applied against
- `auxiliary_columns` These are additional columns to be returned in the output of `Predict` 
- `response_column` This specifies the alias of the response column in the output of `Predict`
- `raw` _(optional)_ Any additional SQL (e.g., a `WHERE` or `ORDER BY` clause) can be added here

See `example.models.yml` for an example.

## API

- `Castpack::prepare_registry()` creates the `${schema}.Models` table and `${schema}.Predict` procedure
- `Castpack::deploy_models()` upserts the models specified in `config.r` to the `Models` table. This function depends on a `models` variable defined in `config.r` that tells Castpack about the models you'd like to load into your database. See `example.config.r` for an example configuration.
