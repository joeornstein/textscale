set.seed(7)
n_docs <- 20
n_dims <- 10

# Random true latent scores so wins are mixed (not all "B")
true_scores <- runif(n_docs)

# Embeddings: true dimension projected into high-dim space with noise
emb <- outer(true_scores, runif(n_dims)) +
  matrix(rnorm(n_docs * n_dims, sd = 0.1), n_docs)
colnames(emb) <- paste0("d", seq_len(n_dims))

# Annotate based on true ordering
comparisons <- generate_comparisons(as.character(seq_len(n_docs)))
comparisons$winner <- ifelse(
  true_scores[comparisons$doc_id_a] > true_scores[comparisons$doc_id_b],
  "A", "B"
)

model <- fit_model(comparisons, emb)

test_that("fit_model returns a textscale_model", {
  expect_s3_class(model, "textscale_model")
  expect_named(model, c("beta", "lambda", "cv_fit", "glmnet_fit"))
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

test_that("validate_model returns expected columns and sane accuracy", {
  result <- validate_model(model, comparisons, emb)
  expect_named(result, c("n_pairs", "n_correct", "accuracy"))
  expect_equal(result$n_pairs, nrow(comparisons))
  expect_gte(result$accuracy, 0.5)
})
