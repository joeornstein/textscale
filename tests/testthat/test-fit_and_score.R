set.seed(7)
n_docs <- 20
n_dims <- 10

# Random true latent scores so wins are mixed (not all "B")
true_scores <- runif(n_docs)

# Embeddings: true dimension projected into high-dim space with noise
emb <- outer(true_scores, runif(n_dims)) +
  matrix(rnorm(n_docs * n_dims, sd = 0.1), n_docs)
colnames(emb) <- paste0("d", seq_len(n_dims))
rownames(emb) <- as.character(seq_len(n_docs))

# Annotate based on true ordering
comparisons <- generate_comparisons(as.character(seq_len(n_docs)))
comparisons$winner <- ifelse(
  true_scores[comparisons$doc_id_a] > true_scores[comparisons$doc_id_b],
  "A", "B"
)

model <- fit_model(comparisons, emb)
model_svm <- fit_model(comparisons, emb, method = "svm")

# --- Ridge (default) ----------------------------------------------------------

test_that("fit_model returns a textscale_model", {
  expect_s3_class(model, "textscale_model")
  expect_named(model, c("beta", "method", "lambda", "cv_fit", "glmnet_fit", "sigma_post"))
})

test_that("ridge model records method", {
  expect_equal(model$method, "ridge")
})

test_that("beta has one entry per embedding dimension", {
  expect_length(model$beta, n_dims)
})

test_that("score_documents returns a numeric vector of correct length", {
  scores <- score_documents(model, emb)
  expect_type(scores, "double")
  expect_length(scores, n_docs)
})

test_that("scores correlate strongly with the true latent dimension", {
  scores <- score_documents(model, emb)
  expect_gt(abs(cor(scores, true_scores)), 0.95)
})

test_that("validate_model returns a textscale_validation object", {
  result <- validate_model(model, comparisons, emb, force = TRUE)
  expect_s3_class(result, "textscale_validation")
  expect_named(result$metrics, c("n_pairs", "n_correct", "accuracy", "ici"))
  expect_equal(result$metrics$n_pairs, nrow(comparisons))
  expect_gte(result$metrics$accuracy, 0.5)
})

# --- SVM ----------------------------------------------------------------------

test_that("fit_model with method='svm' returns a textscale_model", {
  expect_s3_class(model_svm, "textscale_model")
  expect_named(model_svm, c("beta", "method", "svm_fit"))
})

test_that("svm model records method", {
  expect_equal(model_svm$method, "svm")
})

test_that("svm beta has one entry per embedding dimension", {
  expect_length(model_svm$beta, n_dims)
})

test_that("svm scores correlate strongly with the true latent dimension", {
  scores <- score_documents(model_svm, emb)
  expect_gt(abs(cor(scores, true_scores)), 0.95)
})

test_that("validate_model works with svm model", {

  result <- suppressWarnings(validate_model(model_svm, comparisons, emb, force = TRUE))
  expect_s3_class(result, "textscale_validation")
  expect_named(result$metrics, c("n_pairs", "n_correct", "accuracy", "ici"))
})

# --- Confidence intervals (Laplace) ------------------------------------------

test_that("score_documents with ci=TRUE returns a tibble with correct columns", {
  result <- score_documents(model, emb, ci = TRUE)
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("score", "lower", "upper"))
  expect_equal(nrow(result), n_docs)
})

test_that("Laplace CI bounds bracket the point estimate", {
  result <- score_documents(model, emb, ci = TRUE)
  expect_true(all(result$lower <= result$score))
  expect_true(all(result$score <= result$upper))
})

test_that("sigma_post is a square matrix with side n_dims", {
  expect_equal(dim(model$sigma_post), c(n_dims, n_dims))
})

test_that("narrower level produces narrower CI", {
  ci_95 <- score_documents(model, emb, ci = TRUE, level = 0.95)
  ci_50 <- score_documents(model, emb, ci = TRUE, level = 0.50)
  expect_true(all((ci_95$upper - ci_95$lower) >= (ci_50$upper - ci_50$lower)))
})

test_that("Laplace CI errors for SVM model", {
  expect_snapshot(
    error = TRUE,
    score_documents(model_svm, emb, ci = TRUE, ci_method = "laplace")
  )
})

# --- Confidence intervals (bootstrap) ----------------------------------------

test_that("bootstrap CI returns a tibble with correct structure", {
  result <- score_documents(model, emb, ci = TRUE, ci_method = "bootstrap",
                            n_boot = 10, comparisons = comparisons)
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("score", "lower", "upper"))
  expect_equal(nrow(result), n_docs)
})

test_that("bootstrap CI bounds bracket the point estimate", {
  result <- score_documents(model, emb, ci = TRUE, ci_method = "bootstrap",
                            n_boot = 10, comparisons = comparisons)
  expect_true(all(result$lower <= result$score))
  expect_true(all(result$score <= result$upper))
})

test_that("bootstrap CI works for SVM model", {
  result <- score_documents(model_svm, emb, ci = TRUE, ci_method = "bootstrap",
                            n_boot = 10, comparisons = comparisons)
  expect_named(result, c("score", "lower", "upper"))
})

test_that("bootstrap CI errors without comparisons", {
  expect_snapshot(
    error = TRUE,
    score_documents(model, emb, ci = TRUE, ci_method = "bootstrap")
  )
})

# --- Ties --------------------------------------------------------------------

# Create comparisons with some ties mixed in
comparisons_with_ties <- comparisons
tie_idx <- sample(nrow(comparisons_with_ties), 10)
comparisons_with_ties$winner[tie_idx] <- "tie"

test_that("fit_model drops ties and still fits", {
  model_ties <- suppressMessages(fit_model(comparisons_with_ties, emb))
  expect_s3_class(model_ties, "textscale_model")
  expect_length(model_ties$beta, n_dims)
})

test_that("scores from model with ties correlate with true scores", {
  model_ties <- suppressMessages(fit_model(comparisons_with_ties, emb))
  scores <- score_documents(model_ties, emb)
  expect_gt(abs(cor(scores, true_scores)), 0.90)
})

test_that("validate_model drops ties", {
  # Add a split column so validation uses "test" rows
  comp_split <- comparisons_with_ties
  comp_split$split <- sample(c("train", "test"), nrow(comp_split), replace = TRUE, prob = c(0.8, 0.2))
  model_split <- suppressMessages(fit_model(comp_split, emb))
  n_test_ties <- sum(comp_split$split == "test" & comp_split$winner == "tie")

  result <- suppressWarnings(validate_model(model_split, comp_split, emb, force = TRUE))
  expect_equal(result$n_ties_dropped, n_test_ties)
})

test_that("bootstrap CIs work with ties in comparisons", {
  result <- suppressMessages(
    score_documents(model, emb, ci = TRUE, ci_method = "bootstrap",
                    n_boot = 10, comparisons = comparisons_with_ties)
  )
  expect_s3_class(result, "tbl_df")
  expect_named(result, c("score", "lower", "upper"))
})

# --- method argument ----------------------------------------------------------

test_that("fit_model errors on invalid method", {
  expect_snapshot(
    error = TRUE,
    fit_model(comparisons, emb, method = "gbm")
  )
})
