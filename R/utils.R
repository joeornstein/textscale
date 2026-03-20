# Create the parent directory of a file path if it does not already exist.
.ensure_dir <- function(path) {
  dir <- dirname(path)
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
}

# Compute an MD5 hash of one or more strings (concatenated).
# Uses a temp file so no additional package dependencies are needed.
.prompt_hash <- function(...) {
  tmp <- tempfile()
  on.exit(unlink(tmp))
  writeLines(paste(..., sep = "\n"), tmp)
  unname(tools::md5sum(tmp))
}
