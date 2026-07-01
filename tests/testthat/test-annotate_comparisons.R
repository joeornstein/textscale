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
  expect_equal(readRDS(tmp_cache), result)
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
