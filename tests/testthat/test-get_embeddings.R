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

# --- type = "image" ------------------------------------------------------

test_that("type = 'image' dispatches to .fetch_image_embeddings", {
  mock_emb <- matrix(1:4, nrow = 2, dimnames = list(c("img1.png", "img2.png"), NULL))
  local_mocked_bindings(
    .fetch_embeddings       = function(documents, ...) stop("should not be called"),
    .fetch_image_embeddings = function(documents, ...) mock_emb
  )

  result <- get_embeddings(c("img1.png", "img2.png"), cache = NULL, type = "image")
  expect_equal(result, mock_emb)
})

test_that("caching works the same way for type = 'image'", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp))

  mock_emb <- matrix(1:6, nrow = 2, dimnames = list(c("img1.png", "img2.png"), NULL))
  local_mocked_bindings(.fetch_image_embeddings = function(documents, ...) mock_emb)

  expect_message(
    get_embeddings(c("img1.png", "img2.png"), cache = tmp, type = "image"),
    "2 document(s) require embedding",
    fixed = TRUE
  )
  expect_message(
    get_embeddings(c("img1.png", "img2.png"), cache = tmp, type = "image"),
    "2 document(s) loaded from cache",
    fixed = TRUE
  )
})

test_that("model override is forwarded to the fetch function", {
  seen_model <- NULL
  local_mocked_bindings(
    .fetch_image_embeddings = function(documents, model, ...) {
      seen_model <<- model
      matrix(1, nrow = length(documents), dimnames = list(documents, NULL))
    }
  )

  get_embeddings(c("img1.png"), cache = NULL, type = "image", model = "custom-model")
  expect_equal(seen_model, "custom-model")
})
