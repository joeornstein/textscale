docs <- c("cat", "dog", "fish")
comparisons <- generate_comparisons(docs)

test_that("cache is returned immediately when file exists", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp))

  cached <- comparisons
  cached$winner <- "A"
  saveRDS(cached, tmp)

  result <- annotate_comparisons(comparisons, instructions = "irrelevant", cache = tmp, parallel = TRUE)
  expect_equal(result, cached, ignore_attr = TRUE)
})

test_that("cache file is written after annotation", {
  tmp_cache <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp_cache))

  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) rep("A", length(prompts))
  )

  result <- annotate_comparisons(comparisons, instructions = "?", cache = tmp_cache, parallel = TRUE)
  expect_true(file.exists(tmp_cache))
  store <- readRDS(tmp_cache)
  expect_s3_class(store, "textscale_cache")
  expect_length(store, 1)
  expect_equal(store[[1]]$text_a, result$text_a)
  expect_equal(store[[1]]$winner, result$winner)
})

test_that("changing the model does not reuse or discard cached annotations", {
  tmp_cache <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp_cache))

  answer <- "A"
  n_calls <- 0L
  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) {
      n_calls <<- n_calls + 1L
      rep(answer, length(prompts))
    }
  )
  annotate <- function(model) {
    suppressMessages(annotate_comparisons(
      comparisons, instructions = "?", model = model,
      cache = tmp_cache, parallel = TRUE
    ))
  }

  first <- annotate("model-one")
  answer <- "B"
  second <- annotate("model-two")
  expect_equal(n_calls, 2L)
  expect_true(all(first$winner == "A"))
  expect_true(all(second$winner == "B"))
  expect_length(readRDS(tmp_cache), 2)

  # Switching back is a pure cache hit
  third <- annotate("model-one")
  expect_equal(n_calls, 2L)
  expect_true(all(third$winner == "A"))
})

test_that("changing the prompt does not reuse cached annotations", {
  tmp_cache <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp_cache))

  n_calls <- 0L
  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) {
      n_calls <<- n_calls + 1L
      rep("A", length(prompts))
    }
  )

  for (question in c("Which is bigger?", "Which is older?")) {
    suppressMessages(annotate_comparisons(
      comparisons, instructions = question, cache = tmp_cache, parallel = TRUE
    ))
  }
  expect_equal(n_calls, 2L)
})

test_that("cached pairs outside the current run are kept", {
  tmp_cache <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp_cache))

  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) rep("A", length(prompts))
  )

  suppressMessages({
    annotate_comparisons(comparisons, instructions = "?", cache = tmp_cache,
                         parallel = TRUE)
    annotate_comparisons(comparisons[1, ], instructions = "?", cache = tmp_cache,
                         parallel = TRUE)
  })
  expect_equal(nrow(readRDS(tmp_cache)[[1]]), nrow(comparisons))
})

test_that("old-format hashed caches are ignored", {
  tmp_cache <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp_cache))

  old <- comparisons
  old$winner <- "B"
  attr(old, "prompt_hash") <- "old-hash"
  saveRDS(old, tmp_cache)

  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) rep("A", length(prompts))
  )

  expect_message(
    result <- annotate_comparisons(comparisons, instructions = "?",
                                   cache = tmp_cache, parallel = TRUE),
    "earlier version"
  )
  expect_true(all(result$winner == "A"))
  expect_s3_class(readRDS(tmp_cache), "textscale_cache")
})

# --- allow_ties ---------------------------------------------------------------

test_that("allow_ties = TRUE preserves tie responses", {
  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) c("A", "tie", "B")
  )

  result <- annotate_comparisons(comparisons, instructions = "?",
                                 allow_ties = TRUE, parallel = TRUE)
  expect_equal(result$winner, c("A", "tie", "B"))
})

test_that("annotation summary reports total and tie count", {
  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) c("A", "tie", "B")
  )

  expect_message(
    annotate_comparisons(comparisons, instructions = "?",
                         allow_ties = TRUE, parallel = TRUE),
    "3 annotations completed.*1 ties"
  )
})

test_that("annotation summary omits tie count when none", {
  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) c("A", "B", "A")
  )

  expect_message(
    annotate_comparisons(comparisons, instructions = "?",
                         allow_ties = TRUE, parallel = TRUE),
    "3 annotations completed\\."
  )
})

test_that("allow_ties = FALSE warns on tie responses", {
  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) c("A", "Tie", "B")
  )

  expect_warning(
    annotate_comparisons(comparisons, instructions = "?",
                         allow_ties = FALSE, parallel = TRUE),
    "not among"
  )
})

test_that("tie variants are normalised to lowercase 'tie'", {
  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) c("A", " Tie ", "TIE")
  )

  result <- annotate_comparisons(comparisons, instructions = "?",
                                 allow_ties = TRUE, parallel = TRUE)
  expect_equal(result$winner, c("A", "tie", "tie"))
})

# --- document_type = "image" ---------------------------------------------

img_docs <- c("a.png", "b.png", "c.png")
img_comparisons <- generate_comparisons(img_docs)

test_that("document_type = 'image' builds image prompts and skips interpolate", {
  local_mocked_bindings(
    .content_image_file = function(path, ...) {
      ellmer::ContentImageInline(type = "image/png", data = "ZmFrZQ==")
    }
  )

  captured_prompts <- NULL
  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) {
      captured_prompts <<- prompts
      rep("A", length(prompts))
    }
  )

  result <- annotate_comparisons(img_comparisons, instructions = "?",
                                 document_type = "image", parallel = TRUE)

  expect_equal(result$winner, rep("A", nrow(img_comparisons)))
  expect_true(is.list(captured_prompts[[1]]))
  expect_true(inherits(captured_prompts[[1]][[2]], "ellmer::ContentImageInline"))
})

test_that("document_type = 'image' caching works by file path", {
  local_mocked_bindings(
    .content_image_file = function(path, ...) {
      ellmer::ContentImageInline(type = "image/png", data = "ZmFrZQ==")
    }
  )

  tmp_cache <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp_cache))

  local_mocked_bindings(
    .chat_openai = function(...) NULL,
    .parallel_chat_text = function(chat, prompts, ...) rep("A", length(prompts))
  )

  result <- annotate_comparisons(img_comparisons, instructions = "?",
                                 document_type = "image", cache = tmp_cache,
                                 parallel = TRUE)
  expect_true(file.exists(tmp_cache))

  expect_message(
    annotate_comparisons(img_comparisons, instructions = "?",
                         document_type = "image", cache = tmp_cache,
                         parallel = TRUE),
    "comparison(s) loaded from cache",
    fixed = TRUE
  )
})
