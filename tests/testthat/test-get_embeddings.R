test_that("cache is written on first call and read on second", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp))

  mock_emb <- matrix(1:6, nrow = 2, dimnames = list(c("a", "b"), NULL))
  local_mocked_bindings(.fetch_embeddings = function(documents, ...) mock_emb)

  expect_message(
    get_embeddings(c("a", "b"), cache = tmp),
    "2 document(s) require embedding",
    fixed = TRUE
  )
  expect_true(file.exists(tmp))

  expect_message(
    get_embeddings(c("a", "b"), cache = tmp),
    "2 document(s) loaded from cache",
    fixed = TRUE
  )
})

test_that("no cache file is created when cache = NULL", {
  mock_emb <- matrix(1:4, nrow = 2, dimnames = list(c("a", "b"), NULL))
  local_mocked_bindings(.fetch_embeddings = function(documents, ...) mock_emb)

  expect_message(
    result <- get_embeddings(c("a", "b"), cache = NULL),
    "2 document(s) require embedding",
    fixed = TRUE
  )
  expect_equal(result, mock_emb)
})
