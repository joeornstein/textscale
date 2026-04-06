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
#' "wins" on the latent dimension of interest.
#'
#' The simplest way to use this function is to supply `instructions`
#' describing the comparison task in plain language (e.g.,
#' `"Which text is more conservative?"`). The instructions are
#' automatically prepended to the system prompt, and each LLM turn
#' contains the two documents formatted as
#' `"A: <text_a>\\nB: <text_b>"`.
#'
#' For advanced use, the `prompt` argument is an
#' [ellmer::interpolate()] template string that may reference any
#' column in `comparisons` with `{{column_name}}` syntax (most
#' commonly `{{text_a}}` and `{{text_b}}`).
#'
#' By default, annotations are submitted via the OpenAI Batch API
#' ([ellmer::batch_chat_text()]), which is 50% cheaper than standard
#' pricing but may take up to 24 hours to complete. The `path` argument
#' checkpoints batch progress to a `.json` file so interrupted jobs can
#' be resumed without re-calling the API. Set `parallel = TRUE` to use
#' [ellmer::parallel_chat_text()] instead, which returns results
#' immediately at standard API prices.
#'
#' Before sending requests to the API, the function prints an estimated
#' cost based on approximate token counts (1 token ≈ 4 characters) and
#' published OpenAI prices. The estimate assumes one output token per
#' comparison (single-letter response). Prices may be out of date; see
#' <https://openai.com/api/pricing/> for current rates.
#'
#' @param comparisons A tibble produced by
#'   [textscale::generate_comparisons()].
#' @param instructions A plain-language description of the comparison
#'   task (e.g., `"Which text is more conservative?"`). Prepended to
#'   `system_prompt` so the LLM knows what to judge. When using
#'   `annotate_comparisons()` on its own, this is typically the only
#'   argument you need beyond `comparisons`.
#' @param prompt An [ellmer::interpolate()] template string for
#'   formatting each document pair. Defaults to
#'   `"A: {{text_a}}\\nB: {{text_b}}"`. Override this only if you need
#'   a non-standard document layout.
#' @param model Character string naming the OpenAI model to use.
#'   Defaults to `"gpt-4.1-mini"`.
#' @param system_prompt System prompt sent to the LLM. When `NULL`
#'   (the default), an appropriate prompt is generated based on the
#'   `allow_ties` argument. Supply a custom value to override this
#'   behaviour entirely. When `instructions` is supplied, it is
#'   prepended to `system_prompt`.
#' @param path File path for checkpointing batch API calls (passed to
#'   [ellmer::batch_chat_text()]). Defaults to
#'   `"textscale_annotations.json"` in the current working directory.
#'   Set to `NULL` to disable checkpointing. Ignored when
#'   `parallel = TRUE`.
#' @param parallel Logical. If `FALSE` (the default), annotations are
#'   submitted via the OpenAI Batch API at 50% of standard prices.
#'   Set to `TRUE` to use [ellmer::parallel_chat_text()] for immediate
#'   results at standard prices.
#' @param cache Optional path to an `.rds` file. If the file exists,
#'   cached annotations are matched to the incoming `comparisons` by
#'   `text_a` and `text_b`. Rows whose text pair is found in the cache
#'   reuse the stored `winner`; only rows without a cache hit are sent
#'   to the LLM. The updated result (cached + new) is written back to
#'   `cache` after annotation. If `cache` is `NULL` all rows are
#'   annotated and nothing is written to disk. Caches written by
#'   textscale carry a prompt hash and will be ignored if the prompt
#'   changes; externally supplied caches (no hash attribute) bypass
#'   this check.
#' @param ... Additional arguments passed to
#'   [ellmer::batch_chat_text()] or [ellmer::parallel_chat_text()].
#'
#' @param allow_ties Logical. If `TRUE` (the default), the LLM may
#'   respond with `"tie"` when the two texts are indistinguishable on
#'   the dimension of interest. Ties are recorded in the `winner`
#'   column and automatically dropped by downstream functions
#'   ([fit_model()], [validate_model()]). If `FALSE`, the system
#'   prompt instructs the LLM to choose A or B with no ties allowed.
#'   Ignored when a custom `system_prompt` is supplied.
#'
#' @return The input `comparisons` tibble with an additional `winner`
#'   column containing `"A"`, `"B"`, or (when `allow_ties = TRUE`)
#'   `"tie"` for each pair.
#'
#' @export
annotate_comparisons <- function(
    comparisons,
    instructions = NULL,
    prompt = "A: {{text_a}}\nB: {{text_b}}",
    model = "gpt-4.1-mini",
    system_prompt = NULL,
    allow_ties = TRUE,
    path = "textscale_annotations.json",
    parallel = FALSE,
    cache = NULL,
    ...) {

  if (is.null(system_prompt)) {
    system_prompt <- if (allow_ties) {
      "Respond with 'A', 'B', or 'tie'. Use 'tie' only when the two texts are genuinely indistinguishable on the dimension of interest."
    } else {
      "Respond with a single letter ('A' or 'B') only. No ties allowed."
    }
  }

  if (!is.null(instructions)) {
    system_prompt <- paste0(instructions, "\n", system_prompt)
  }

  hash <- .prompt_hash(prompt, system_prompt)

  # Start with all winners unknown
  comparisons$winner <- NA_character_

  # Recover cached winners, but only if the cache was created with the
  # same prompt and system_prompt (checked via stored MD5 hash attribute).
  if (!is.null(cache) && file.exists(cache)) {
    cached      <- readRDS(cache)
    cached_hash <- attr(cached, "prompt_hash")
    if (!is.null(cached_hash) && !identical(cached_hash, hash)) {
      message("Prompt has changed; ignoring cached annotations.")
      cached <- NULL
    } else if ("winner" %in% names(cached)) {
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
      attr(comparisons, "prompt_hash") <- hash
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

  cost_msg <- .cost_estimate_message(prompts, system_prompt, model, batch = !parallel)
  if (!is.null(cost_msg)) message(cost_msg)

  responses <- if (parallel) {
    .parallel_chat_text(chat, prompts, ...)
  } else {
    .batch_chat_text(chat, prompts, path = path, ...)
  }

  cleaned <- trimws(responses)
  # Normalise common tie variants
  cleaned <- ifelse(tolower(cleaned) == "tie", "tie", cleaned)
  valid_values <- if (allow_ties) c("A", "B", "tie") else c("A", "B")
  bad <- !cleaned %in% valid_values
  if (any(bad)) {
    n_bad <- sum(bad)
    examples <- unique(cleaned[bad])
    if (length(examples) > 5) examples <- c(examples[1:5], "...")
    warning(
      n_bad, " response(s) were not among {",
      paste(valid_values, collapse = ", "), "}: ",
      paste(examples, collapse = ", "), ". These will appear as-is in the `winner` column."
    )
  }
  comparisons$winner[needs_annotation] <- cleaned

  if (!is.null(cache)) {
    attr(comparisons, "prompt_hash") <- hash
    .ensure_dir(cache)
    saveRDS(comparisons, cache)
  }

  comparisons
}
