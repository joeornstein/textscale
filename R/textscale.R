#' Measure a latent quantity from text
#'
#' Runs the full textscale pipeline in a single call: generates pairwise
#' comparisons, retrieves embeddings, annotates pairs with an LLM, fits
#' and validates a model on the train/test split, refits on all
#' comparisons, and returns scores for every document.
#'
#' @param documents A character vector of documents to scale. When
#'   `document_type = "image"`, a character vector of paths to local
#'   image files.
#' @param prompt Instruction text for the LLM annotator. Should be a
#'   plain question or directive describing which document should be
#'   judged "greater" on the latent dimension — no placeholder syntax
#'   needed. For example: `"Which political ad is more negative toward
#'   its opponent?"`. The document text (or, for images, the images
#'   themselves) is appended automatically as labelled options A and B.
#' @param document_type One of `"text"` (default) or `"image"`. When
#'   `"image"`, `documents` are treated as local image file paths:
#'   embeddings are retrieved via OpenRouter's multimodal embeddings
#'   endpoint (requires `OPENROUTER_API_KEY`) and the LLM annotator is
#'   shown the images directly instead of interpolated text. See
#'   [get_embeddings()] and [annotate_comparisons()] for details.
#' @param embedding_model Character string naming the embedding model to
#'   use. When `NULL` (the default), [get_embeddings()] picks a built-in
#'   default based on `document_type`.
#' @param prop Proportion of documents assigned to the training split.
#'   Defaults to `0.8`. Cannot be used together with `holdout`.
#' @param holdout Optional logical vector the same length as `documents`.
#'   `TRUE` marks a document for the test set, `FALSE` for the training
#'   set. When supplied, overrides `prop` for train/test assignment.
#'   Cannot be used together with `prop`.
#' @param blocks Optional vector (character, factor, or integer) the same
#'   length as `documents`. When supplied, only within-block pairs are
#'   generated. See [generate_comparisons()] for details.
#' @param n_train Maximum number of training comparison pairs to
#'   generate. Defaults to `10000`.
#' @param n_test Maximum number of test comparison pairs to generate.
#'   Defaults to `5000`.
#' @param seed Integer random seed for reproducible pair sampling.
#'   Defaults to `NULL`.
#' @param llm_model OpenAI model name used for annotation. Defaults to
#'   `"gpt-5.4-mini"`.
#' @param embeddings_cache File path for caching embeddings as an RDS
#'   file. Passed to [get_embeddings()]. Defaults to
#'   `"textscale_embeddings.rds"` in the current working directory.
#'   Set to `NULL` to disable caching.
#' @param annotations_cache File path for caching annotations as an RDS
#'   file. Passed to [annotate_comparisons()]. Defaults to
#'   `"textscale_annotations.rds"` in the current working directory.
#'   Set to `NULL` to disable caching.
#' @param annotations_path File path for checkpointing batch API calls.
#'   Passed to [annotate_comparisons()] as `path`. Defaults to
#'   `"textscale_annotations.json"` in the current working directory.
#'   Set to `NULL` to disable checkpointing. Ignored when
#'   `parallel = TRUE`.
#' @param parallel Logical. If `FALSE` (the default), annotations are
#'   submitted via the OpenAI Batch API at 50% of standard prices.
#'   Set to `TRUE` to use [ellmer::parallel_chat_text()] for immediate
#'   results at standard prices.
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
#' @param allow_ties Logical. If `TRUE` (the default), the LLM may
#'   respond with `"tie"` when the two texts are indistinguishable.
#'   Ties are automatically dropped before model fitting and
#'   validation. Set to `FALSE` to force a choice between A and B.
#'   Passed to [annotate_comparisons()].
#' @param force Logical. If `FALSE` (the default), the pipeline stops
#'   when validation metrics are poor (accuracy < 0.55 or ICI > 0.20)
#'   and warns when they are marginal (accuracy < 0.65 or ICI > 0.10).
#'   Set `force = TRUE` to downgrade stops to warnings and continue
#'   scoring regardless of validation results. Ignored when
#'   `validate = FALSE`.
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
    document_type = c("text", "image"),
    prop = 0.8,
    holdout = NULL,
    blocks = NULL,
    n_train = 10000,
    n_test = 5000,
    seed = NULL,
    llm_model = "gpt-5.4-mini",
    embedding_model = NULL,
    embeddings_cache = "textscale_embeddings.rds",
    annotations_cache = "textscale_annotations.rds",
    annotations_path = "textscale_annotations.json",
    parallel = FALSE,
    allow_ties = TRUE,
    method = "ridge",
    ci = TRUE,
    ci_method = "laplace",
    validate = TRUE,
    force = FALSE,
    ...) {

  document_type <- match.arg(document_type)

  # When holdout is supplied, don't pass prop
  use_prop <- if (!is.null(holdout)) NULL else prop

  # Step 1: Generate pairwise comparisons with train/test split
  comparisons <- generate_comparisons(
    documents,
    n_train = n_train,
    n_test  = n_test,
    prop    = use_prop,
    holdout = holdout,
    blocks  = blocks,
    seed    = seed
  )

  # Step 2: Retrieve embeddings
  embeddings <- get_embeddings(
    documents,
    cache = embeddings_cache,
    type  = document_type,
    model = embedding_model
  )

  # Step 3: Annotate comparisons with LLM
  comparisons <- annotate_comparisons(
    comparisons,
    instructions  = prompt,
    model         = llm_model,
    document_type = document_type,
    allow_ties    = allow_ties,
    cache         = annotations_cache,
    path          = annotations_path,
    parallel      = parallel
  )

  # Step 4: Fit evaluation model on training split
  model_eval <- fit_model(comparisons, embeddings, method = method, ...)

  # Step 5: Validate on held-out test split
  metrics <- if (validate) {
    validate_model(model_eval, comparisons, embeddings, force = force)
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
  n_comparisons <- nrow(x$comparisons)
  n_ties <- sum(x$comparisons$winner == "tie", na.rm = TRUE)
  if (n_ties > 0) {
    cat(sprintf(
      "  Comparisons:       %s (%s ties, %.1f%%)\n",
      format(n_comparisons, big.mark = ","),
      format(n_ties, big.mark = ","),
      100 * n_ties / n_comparisons
    ))
  }
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
