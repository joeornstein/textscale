test_that(".fetch_image_embeddings errors without an API key", {
  withr::local_envvar(OPENROUTER_API_KEY = "")
  expect_error(
    .fetch_image_embeddings(c("a.png")),
    "OPENROUTER_API_KEY"
  )
})

test_that(".fetch_image_embeddings returns a matrix keyed by document path", {
  withr::local_envvar(OPENROUTER_API_KEY = "fake-key")
  local_mocked_bindings(
    .content_image_file = function(path, ...) {
      ellmer::ContentImageInline(type = "image/png", data = "ZmFrZQ==")
    }
  )
  httr2::local_mocked_responses(function(req) {
    httr2::response_json(body = list(
      data = list(
        list(embedding = as.list(1:3), index = 0),
        list(embedding = as.list(4:6), index = 1)
      )
    ))
  })

  result <- .fetch_image_embeddings(c("a.png", "b.png"))
  expect_equal(dim(result), c(2, 3))
  expect_equal(rownames(result), c("a.png", "b.png"))
  expect_equal(unname(result[1, ]), c(1, 2, 3))
  expect_equal(unname(result[2, ]), c(4, 5, 6))
})

test_that(".fetch_image_embeddings chunks large document sets", {
  withr::local_envvar(OPENROUTER_API_KEY = "fake-key")
  local_mocked_bindings(
    .content_image_file = function(path, ...) {
      ellmer::ContentImageInline(type = "image/png", data = "ZmFrZQ==")
    }
  )

  n_requests <- 0
  httr2::local_mocked_responses(function(req) {
    n_requests <<- n_requests + 1
    n <- length(req$body$data$input)
    httr2::response_json(body = list(
      data = lapply(seq_len(n), function(i) list(embedding = list(i), index = i - 1))
    ))
  })

  docs <- paste0("img", 1:45, ".png")
  result <- .fetch_image_embeddings(docs, chunk_size = 20)
  expect_equal(nrow(result), 45)
  expect_equal(rownames(result), docs)
  expect_equal(n_requests, 3)
})

test_that(".fetch_image_embeddings surfaces API errors", {
  withr::local_envvar(OPENROUTER_API_KEY = "fake-key")
  local_mocked_bindings(
    .content_image_file = function(path, ...) {
      ellmer::ContentImageInline(type = "image/png", data = "ZmFrZQ==")
    }
  )
  httr2::local_mocked_responses(function(req) httr2::response_json(status_code = 401, body = list()))

  expect_error(.fetch_image_embeddings(c("a.png")), "401")
})
