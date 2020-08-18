#' @title Read a model configuration file
#' @param path A character vector representing the path to a YAML file with model configuration details
#' @return An parsed YAML object
read_config <- function(path="models.yml") {
  return(yaml::yaml.load_file(path))
}
