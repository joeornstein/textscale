#' @keywords internal
#' @export
.fetch_embeddings <- function(documents, ...) {
  fuzzylink::get_embeddings(documents, ...)
}

#' @keywords internal
#' @export
.fetch_image_embeddings <- function(documents, model = "google/gemini-embedding-2",
                                     resize = "high", chunk_size = 20, ...) {
  api_key <- Sys.getenv("OPENROUTER_API_KEY")
  if (api_key == "") {
    stop(
      "No API key detected. Set OPENROUTER_API_KEY in .Renviron or pass ",
      "as an environment variable.",
      call. = FALSE
    )
  }

  to_data_uri <- function(path) {
    img <- .content_image_file(path, resize = resize)
    paste0("data:", img@type, ";base64,", img@data)
  }

  build_request <- function(paths, base_url = "https://openrouter.ai/api/v1/embeddings") {
    input <- lapply(paths, function(path) {
      list(content = list(list(
        type      = "image_url",
        image_url = list(url = to_data_uri(path))
      )))
    })
    body <- c(list(model = model, input = input), list(...))

    httr2::req_retry(
      httr2::req_body_json(
        httr2::req_headers(
          httr2::request(base_url),
          Authorization = paste("Bearer", api_key)
        ),
        body
      ),
      max_tries = 5,
      is_transient = function(resp) httr2::resp_status(resp) %in% c(429, 500:504)
    )
  }

  chunks <- split(documents, ceiling(seq_along(documents) / chunk_size))
  reqs   <- lapply(chunks, build_request)
  resps  <- httr2::req_perform_parallel(reqs, max_active = 5, on_error = "continue")

  status_codes <- vapply(resps, function(x) x$status, numeric(1))
  if (any(status_codes == 400)) {
    stop("HTTP 400 Bad Request. Likely due to malformed input or an unsupported image format.")
  } else if (any(status_codes == 401)) {
    stop("401 Unauthorized. Your OPENROUTER_API_KEY is missing, invalid, or expired.")
  } else if (any(status_codes == 429)) {
    stop("429 Too Many Requests. Rate limit exceeded; try again later.")
  } else if (any(status_codes >= 500)) {
    stop("Server error (5xx) from OpenRouter. Try again later.")
  }

  embeddings <- lapply(resps, function(resp) {
    data <- httr2::resp_body_json(resp)$data
    do.call(rbind, lapply(data, function(x) unlist(x$embedding)))
  })

  mat <- do.call(rbind, embeddings)
  rownames(mat) <- documents
  mat
}

#' Get text embeddings with optional caching
#'
#' A thin wrapper around [fuzzylink::get_embeddings()] that adds
#' file-based caching. If `cache` points to an existing file, embeddings
#' for documents already present in the cache are loaded from disk.
#' Embeddings for any documents not found in the cache are fetched via
#' the API and appended to the cache before returning.
#'
#' @param documents A character vector of texts to embed. When
#'   `type = "image"`, a character vector of paths to local image files.
#' @param cache Optional path to an `.rds` file. If the file exists,
#'   cached embeddings matching `documents` (by row name) are reused.
#'   Any new documents are fetched and written back to the cache. If
#'   `NULL`, embeddings are always computed fresh without caching.
#' @param type One of `"text"` (default) or `"image"`. `"text"` embeds
#'   `documents` via [fuzzylink::get_embeddings()] (OpenAI/Mistral text
#'   embeddings). `"image"` treats `documents` as local image file paths
#'   and embeds them via OpenRouter's multimodal embeddings endpoint,
#'   which requires an `OPENROUTER_API_KEY` environment variable.
#' @param model Character string naming the embedding model to use. When
#'   `NULL` (the default), each `type` uses its own built-in default:
#'   `"text-embedding-3-large"` for `type = "text"`, or
#'   `"google/gemini-embedding-2"` for `type = "image"`.
#' @param ... Additional arguments passed to
#'   [fuzzylink::get_embeddings()] (for `type = "text"`) or to the
#'   internal OpenRouter request body (for `type = "image"`).
#'
#' @return A numeric matrix with one row per document and one column
#'   per embedding dimension. Row names are set to `documents`.
#'
#' @export
get_embeddings <- function(documents, cache = NULL, type = c("text", "image"),
                           model = NULL, ...) {
  type <- match.arg(type)
  fetch_fn <- if (type == "image") .fetch_image_embeddings else .fetch_embeddings

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
    fetch_args <- c(list(new_documents), if (!is.null(model)) list(model = model), list(...))
    new_emb <- do.call(fetch_fn, fetch_args)

    cached <- if (!is.null(cached)) rbind(cached, new_emb) else new_emb

    if (!is.null(cache)) {
      .ensure_dir(cache)
      saveRDS(cached, cache)
    }
  }

  cached[documents, , drop = FALSE]
}
