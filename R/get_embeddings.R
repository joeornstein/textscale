#' Get text embeddings with optional caching
#'
#' A thin wrapper around [fuzzylink::get_embeddings()] that adds
#' file-based caching. If `cache` points to an existing file, embeddings
#' for documents already present in the cache are loaded from disk.
#' Embeddings for any documents not found in the cache are fetched via
#' the API and appended to the cache before returning.
#'
#' @param documents A character vector of texts to embed.
#' @param cache Optional path to an `.rds` file. If the file exists,
#'   cached embeddings matching `documents` (by row name) are reused.
#'   Any new documents are fetched and written back to the cache. If
#'   `NULL`, embeddings are always computed fresh without caching.
#' @param ... Additional arguments passed to
#'   [fuzzylink::get_embeddings()].
#'
#' @return A numeric matrix with one row per document and one column
#'   per embedding dimension. Row names are set to `documents`.
#'
#' @export
# Internal wrapper around fuzzylink::get_embeddings to allow mocking in tests.
.fetch_embeddings <- function(documents, ...) {
  fuzzylink::get_embeddings(documents, ...)
}

get_embeddings <- function(documents, cache = NULL, ...) {
  cached <- NULL
  if (!is.null(cache) && file.exists(cache)) {
    cached <- readRDS(cache)
  }

  new_documents <- if (!is.null(cached)) {
    documents[!documents %in% rownames(cached)]
  } else {
    documents
  }

  n_cached <- length(documents) - length(new_documents)
  n_new    <- length(new_documents)

  if (n_cached > 0) message(n_cached, " document(s) loaded from cache.")
  if (n_new    > 0) message(n_new,    " document(s) require embedding.")

  if (length(new_documents) > 0) {
    new_emb <- .fetch_embeddings(new_documents, ...)

    cached <- if (!is.null(cached)) rbind(cached, new_emb) else new_emb

    if (!is.null(cache)) {
      saveRDS(cached, cache)
    }
  }

  cached[documents, , drop = FALSE]
}
