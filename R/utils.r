read_config <- function(path="models.yml") {
  return(yaml::yaml.load_file(path))
}