# Create the parent directory of a file path if it does not already exist.
.ensure_dir <- function(path) {
  dir <- dirname(path)
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
}
