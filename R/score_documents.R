#' Score documents on the latent dimension
#'
#' Projects document embeddings onto the latent dimension identified by
#' a fitted textscale model. Scores are the linear predictor
#' `embeddings %*% beta` (i.e., log-odds, without the intercept), and
#' are therefore comparable across documents but arbitrary up to a
#' linear transformation.
#'
#' @param model A `textscale_model` object produced by
#'   [textscale::fit_model()].
#' @param embeddings A numeric matrix of document embeddings to score,
#'   with one row per document.
#'
#' @return A numeric vector of latent dimension scores, one per
#'   document.
#'
#' @export
score_documents <- function(model, embeddings) {
  as.numeric(embeddings %*% model$beta)
}
