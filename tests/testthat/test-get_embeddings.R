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

test_that("different models get separate cache entries in one file", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp))

  n_calls <- 0L
  local_mocked_bindings(.fetch_embeddings = function(documents, model, ...) {
    n_calls <<- n_calls + 1L
    value <- if (model == "model-one") 1 else 2
    matrix(value, nrow = length(documents), ncol = 2, dimnames = list(documents, NULL))
  })
  embed <- function(docs, model) {
    suppressMessages(get_embeddings(docs, cache = tmp, model = model))
  }

  first <- embed(c("a", "b"), "model-one")
  # Overlapping documents with a second model must not mix vectors
  second <- embed(c("a", "c"), "model-two")
  expect_equal(n_calls, 2L)
  expect_true(all(first == 1))
  expect_true(all(second == 2))
  expect_length(readRDS(tmp), 2)

  # Switching back is a pure cache hit
  third <- embed(c("a", "b"), "model-one")
  expect_equal(n_calls, 2L)
  expect_true(all(third == 1))
})

test_that("models with different dimensions coexist", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp))

  local_mocked_bindings(.fetch_embeddings = function(documents, model, ...) {
    matrix(1, nrow = length(documents), ncol = if (model == "small") 2 else 4,
           dimnames = list(documents, NULL))
  })

  suppressMessages({
    get_embeddings(c("a"), cache = tmp, model = "small")
    result <- get_embeddings(c("a", "b"), cache = tmp, model = "large")
  })
  expect_equal(ncol(result), 4)
})

test_that("NULL model shares a cache entry with its explicit default", {
  expect_identical(
    .embedding_cache_key("text", NULL, list()),
    .embedding_cache_key("text", "text-embedding-3-large", list())
  )
  expect_identical(
    .embedding_cache_key("image", NULL, list()),
    .embedding_cache_key("image", "google/gemini-embedding-2", list())
  )
})

test_that("cache key reflects arguments that change the vectors only", {
  base <- .embedding_cache_key("text", "m", list(dimensions = 256))
  expect_false(identical(base, .embedding_cache_key("text", "m", list(dimensions = 512))))
  expect_false(identical(base, .embedding_cache_key("image", "m", list(dimensions = 256))))
  expect_identical(
    base,
    .embedding_cache_key("text", "m", list(parallel = FALSE, dimensions = 256,
                                           openai_api_key = "secret"))
  )
})

test_that("old matrix caches are reused with a warning and migrated", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp))

  old <- matrix(1:4, nrow = 2, dimnames = list(c("a", "b"), NULL))
  saveRDS(old, tmp)
  local_mocked_bindings(.fetch_embeddings = function(documents, ...) stop("should not be called"))

  expect_warning(
    suppressMessages(result <- get_embeddings(c("a", "b"), cache = tmp)),
    "does not record which model"
  )
  expect_equal(result, old)
  expect_s3_class(readRDS(tmp), "textscale_cache")

  # Migrated, so the warning does not repeat
  expect_no_warning(suppressMessages(get_embeddings(c("a", "b"), cache = tmp)))
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
