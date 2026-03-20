#' @keywords internal
#' @export
.chat_openai <- function(...) ellmer::chat_openai(...)

#' @keywords internal
#' @export
.batch_chat_text <- function(...) ellmer::batch_chat_text(...)

#' @keywords internal
#' @export
.parallel_chat_text <- function(...) ellmer::parallel_chat_text(...)

# Published OpenAI prices in USD per million tokens (standard rate).
# Batch API is 50% cheaper. Update as prices change.
.model_prices <- list(
  "gpt-5.4"      = c(input = 2.50, output = 15.00),
  "gpt-5.2"      = c(input = 1.75, output = 14.00),
  "gpt-5"        = c(input = 1.25, output = 10.00),
  "gpt-5-mini"   = c(input = 0.25, output =  2.00),
  "gpt-5-nano"   = c(input = 0.05, output =  0.40),
  "gpt-4.1"      = c(input = 2.00, output =  8.00),
  "gpt-4.1-mini" = c(input = 0.40, output =  1.60),
  "gpt-4.1-nano" = c(input = 0.10, output =  0.40),
  "gpt-4o"       = c(input = 2.50, output = 10.00),
  "gpt-4o-mini"  = c(input = 0.15, output =  0.60)
)

# Build a cost-estimate message for a set of interpolated prompts.
# Returns NULL silently when the model is not in the pricing table.
.cost_estimate_message <- function(prompts, system_prompt, model, batch = FALSE) {
  if (!model %in% names(.model_prices)) return(NULL)

  p <- .model_prices[[model]]
  if (batch) p <- p * 0.5

  # Approximate token counts: ~4 characters per token.
  n             <- length(prompts)
  input_tokens  <- (sum(nchar(unlist(prompts))) + n * nchar(system_prompt)) / 4
  output_tokens <- n  # single-letter response

  cost <- (input_tokens / 1e6) * p["input"] + (output_tokens / 1e6) * p["output"]

  mode_note <- if (batch) " (batch pricing, 50% discount applied)" else ""
  sprintf(
    "Estimated API cost: ~$%.4g for %s new comparison(s) using %s%s. Prices are approximate; see https://openai.com/api/pricing/ for current rates.",
    cost, format(n, big.mark = ","), model, mode_note
  )
}

#' Annotate pairwise comparisons using an LLM
#'
#' Submits each comparison pair to an LLM and records which document
#' "wins" on the latent dimension of interest. The `prompt` is
#' interpolated for each row using [ellmer::interpolate()], so it may
#' reference any column in `comparisons` with `{{column_name}}` syntax.
#' Most prompts will use `{{text_a}}` and `{{text_b}}`.
#'
#' When `path` is supplied the underlying [ellmer::batch_chat_text()]
#' call caches its results to that file, so interrupted jobs can be
#' resumed without re-calling the API.
#'
#' Before sending requests to the API, the function prints an estimated
#' cost based on approximate token counts (1 token ≈ 4 characters) and
#' published OpenAI prices. The estimate assumes one output token per
#' comparison (single-letter response). Prices may be out of date; see
#' <https://openai.com/api/pricing/> for current rates.
#'
#' @param comparisons A tibble produced by
#'   [textscale::generate_comparisons()].
#' @param prompt An [ellmer::interpolate()] template string. Use
#'   `{{text_a}}` and `{{text_b}}` to reference the two documents being
#'   compared. Example: `"Which is heavier?\\nA: {{text_a}}\\nB:
#'   {{text_b}}"`.
#' @param model Character string naming the OpenAI model to use.
#'   Defaults to `"gpt-4.1-mini"`.
#' @param system_prompt System prompt sent to the LLM. Defaults to
#'   instructing the model to respond with a single letter.
#' @param path Optional file path for checkpointing batch API calls
#'   (passed to [ellmer::batch_chat_text()]). Useful for resuming
#'   interrupted runs. If `NULL`, uses [ellmer::parallel_chat_text()]
#'   instead.
#' @param cache Optional path to an `.rds` file. If the file exists,
#'   cached annotations are matched to the incoming `comparisons` by
#'   `text_a` and `text_b`. Rows whose text pair is found in the cache
#'   reuse the stored `winner`; only rows without a cache hit are sent
#'   to the LLM. The updated result (cached + new) is written back to
#'   `cache` after annotation. If `cache` is `NULL` all rows are
#'   annotated and nothing is written to disk.
#' @param ... Additional arguments passed to
#'   [ellmer::batch_chat_text()] or [ellmer::parallel_chat_text()].
#'
#' @return The input `comparisons` tibble with an additional `winner`
#'   column containing `"A"` or `"B"` for each pair.
#'
#' @export
annotate_comparisons <- function(
    comparisons,
    prompt,
    model = "gpt-4.1-mini",
    system_prompt = "Respond with a single letter ('A' or 'B') only. No ties allowed.",
    path = NULL,
    cache = NULL,
    ...) {

  # Start with all winners unknown
  comparisons$winner <- NA_character_

  # Recover cached winners by matching on text content
  if (!is.null(cache) && file.exists(cache)) {
    cached <- readRDS(cache)
    if ("winner" %in% names(cached)) {
      key_new    <- paste(comparisons$text_a, comparisons$text_b, sep = "\t")
      key_cached <- paste(cached$text_a,      cached$text_b,      sep = "\t")
      idx <- match(key_new, key_cached)
      comparisons$winner <- cached$winner[idx]
    }
  }

  needs_annotation <- is.na(comparisons$winner)
  n_cached <- sum(!needs_annotation)
  n_new    <- sum(needs_annotation)

  if (n_cached > 0) message(n_cached, " comparison(s) loaded from cache.")
  if (n_new    > 0) message(n_new,    " comparison(s) require annotation.")

  if (n_new == 0) {
    if (!is.null(cache)) {
      .ensure_dir(cache)
      saveRDS(comparisons, cache)
    }
    return(comparisons)
  }

  # Annotate only uncached rows
  new_rows <- comparisons[needs_annotation, ]
  chat <- .chat_openai(system_prompt, model = model)
  prompts <- do.call(
    ellmer::interpolate,
    c(list(prompt), as.list(new_rows))
  )

  cost_msg <- .cost_estimate_message(prompts, system_prompt, model, batch = !is.null(path))
  if (!is.null(cost_msg)) message(cost_msg)

  responses <- if (!is.null(path)) {
    .batch_chat_text(chat, prompts, path = path, ...)
  } else {
    .parallel_chat_text(chat, prompts, ...)
  }

  comparisons$winner[needs_annotation] <- trimws(responses)

  if (!is.null(cache)) {
    .ensure_dir(cache)
    saveRDS(comparisons, cache)
  }

  comparisons
}
