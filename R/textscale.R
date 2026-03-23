#' Measure a latent quantity from text
#'
#' Runs the full textscale pipeline in a single call: generates pairwise
#' comparisons, retrieves embeddings, annotates pairs with an LLM, fits
#' and validates a model on the train/test split, refits on all
#' comparisons, and returns scores for every document.
#'
#' @param documents A character vector of documents to scale.
#' @param prompt Instruction text for the LLM annotator. Should be a
#'   plain question or directive describing which document should be
#'   judged "greater" on the latent dimension — no placeholder syntax
#'   needed. For example: `"Which political ad is more negative toward
#'   its opponent?"`. The document text is appended automatically as
#'   labelled options A and B.
#' @param prop Proportion of documents assigned to the training split.
#'   Defaults to `0.8`.
#' @param n_train Maximum number of training comparison pairs to
#'   generate. Defaults to `10000`.
#' @param n_test Maximum number of test comparison pairs to generate.
#'   Defaults to `5000`.
#' @param seed Integer random seed for reproducible pair sampling.
#'   Defaults to `NULL`.
#' @param llm_model OpenAI model name used for annotation. Defaults to
#'   `"gpt-4.1-mini"`.
#' @param embeddings_cache File path for caching embeddings as an RDS
#'   file. Passed to [get_embeddings()]. Defaults to
#'   `"textscale_embeddings.rds"` in the current working directory.
#'   Set to `NULL` to disable caching.
#' @param annotations_cache File path for caching annotations as an RDS
#'   file. Passed to [annotate_comparisons()]. Defaults to
#'   `"textscale_annotations.rds"` in the current working directory.
#'   Set to `NULL` to disable caching.
#' @param annotations_path File path for checkpointing batch API calls.
#'   Passed to `annotate_comparisons()` as `path`. Recommended for
#'   runs with more than ~5,000 pairs. Defaults to `NULL`.
#' @param method Fitting method passed to [fit_model()]. One of
#'   `"ridge"` (default), `"lasso"`, `"enet"`, or `"svm"`.
#' @param ci Logical. If `TRUE`, the `scores` element of the returned
#'   object is a tibble with `score`, `lower`, and `upper` columns.
#'   Defaults to `TRUE`.
#' @param ci_method Method for computing confidence intervals. One of
#'   `"laplace"` (default) or `"bootstrap"`. Passed to
#'   [score_documents()]. Ignored when `ci = FALSE`.
#' @param validate Logical. If `TRUE` (the default), [validate_model()]
#'   is called on the held-out test split and its output is printed.
#' @param ... Additional arguments passed to [fit_model()] (e.g.
#'   `alpha`, `nlambda`, `lambda_min_ratio`).
#'
#' @return A `textscale_result` object (a list) containing:
#'   \describe{
#'     \item{`scores`}{Document scores on the latent dimension. A named
#'       numeric vector by default, or a tibble with `score`, `lower`,
#'       and `upper` if `ci = TRUE`.}
#'     \item{`model_final`}{The `textscale_model` fit on all comparisons,
#'       used to produce `scores`. Pass to [score_documents()] to scale
#'       new documents.}
#'     \item{`model_eval`}{The `textscale_model` fit on training
#'       comparisons only, used for validation.}
#'     \item{`validation`}{A `textscale_validation` object from
#'       [validate_model()], or `NULL` if `validate = FALSE`. Call
#'       [print()] on it for metrics and [plot()] for the calibration
#'       plot.}
#'     \item{`comparisons`}{The annotated comparisons tibble.}
#'     \item{`embeddings`}{The document embedding matrix.}
#'   }
#'
#' @export
textscale <- function(
    documents,
    prompt,
    prop = 0.8,
    n_train = 10000,
    n_test = 5000,
    seed = NULL,
    llm_model = "gpt-4.1-mini",
    embeddings_cache = "textscale_embeddings.rds",
    annotations_cache = "textscale_annotations.rds",
    annotations_path = NULL,
    method = "ridge",
    ci = TRUE,
    ci_method = "laplace",
    validate = TRUE,
    ...) {

  # Task instruction goes in the system prompt; each turn contains only
  # the document pair. This keeps per-call content minimal and separates
  # "what to do" from "the data".
  system_prompt <- paste0(
    prompt,
    "\nRespond with a single letter ('A' or 'B') only. No ties allowed."
  )

  # Step 1: Generate pairwise comparisons with train/test split
  comparisons <- generate_comparisons(
    documents,
    n_train = n_train,
    n_test  = n_test,
    prop    = prop,
    seed    = seed
  )

  # Step 2: Retrieve text embeddings
  embeddings <- get_embeddings(documents, cache = embeddings_cache)

  # Step 3: Annotate comparisons with LLM
  comparisons <- annotate_comparisons(
    comparisons,
    prompt        = "A: {{text_a}}\nB: {{text_b}}",
    system_prompt = system_prompt,
    model         = llm_model,
    cache         = annotations_cache,
    path          = annotations_path
  )

  # Step 4: Fit evaluation model on training split
  model_eval <- fit_model(comparisons, embeddings, method = method, ...)

  # Step 5: Validate on held-out test split
  metrics <- if (validate) {
    validate_model(model_eval, comparisons, embeddings)
  } else {
    NULL
  }

  # Step 6: Refit on all comparisons
  model_final <- fit_model(
    comparisons, embeddings,
    method = method,
    refit  = TRUE,
    ...
  )

  # Step 7: Score all documents
  scores <- score_documents(model_final, embeddings, ci = ci,
                            ci_method = ci_method,
                            comparisons = comparisons)

  structure(
    list(
      scores      = scores,
      model_final = model_final,
      model_eval  = model_eval,
      validation  = metrics,
      comparisons = comparisons,
      embeddings  = embeddings
    ),
    class = "textscale_result"
  )
}

#' @export
plot.textscale_result <- function(x, ...) {
  if (is.null(x$validation)) {
    stop("No validation object found. Re-run textscale() with validate = TRUE.")
  }
  plot(x$validation, ...)
}

#' @export
print.textscale_result <- function(x, ...) {
  n <- if (is.data.frame(x$scores)) nrow(x$scores) else length(x$scores)
  cat("textscale result\n")
  cat(sprintf("  Documents scored:  %s\n", format(n, big.mark = ",")))
  if (!is.null(x$validation)) {
    m <- x$validation$metrics
    cat(sprintf(
      "  Validation:        %.1f%% accuracy on %s test pairs (ICI = %.3f)\n",
      100 * m$accuracy,
      format(m$n_pairs, big.mark = ","),
      m$ici
    ))
  }
  invisible(x)
}
