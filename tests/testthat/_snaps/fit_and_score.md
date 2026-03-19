# Laplace CI errors for SVM model

    Code
      score_documents(model_svm, emb, ci = TRUE, ci_method = "laplace")
    Condition
      Error in `score_documents()`:
      ! Laplace CIs are not available for method = 'svm'. Use ci_method = 'bootstrap' instead.

# bootstrap CI errors without comparisons

    Code
      score_documents(model, emb, ci = TRUE, ci_method = "bootstrap")
    Condition
      Error in `score_documents()`:
      ! `comparisons` must be supplied when ci_method = 'bootstrap'.

# fit_model errors on invalid method

    Code
      fit_model(comparisons, emb, method = "gbm")
    Condition
      Error in `match.arg()`:
      ! 'arg' should be one of "ridge", "lasso", "enet", "svm"

