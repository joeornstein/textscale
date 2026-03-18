#' Generate pairwise comparisons from a set of documents
#'
#' Samples unique pairs of documents to be used as input to
#' [textscale::annotate_comparisons()]. Each row of the returned tibble
#' represents one comparison between two documents.
#'
#' When `prop` is supplied, documents are randomly partitioned into
#' training and test sets. Up to `n_train` within-train pairs and up to
#' `n_test` within-test pairs are sampled, and a `split` column
#' (`"train"` / `"test"`) is added to the result.
#' [textscale::fit_model()] and [textscale::validate_model()] both
#' respect this column automatically.
#'
#' When fewer unique pairs exist than the requested `n_train` or
#' `n_test`, all available pairs are returned with a message.
#'
#' @param documents A character vector of documents to compare.
#' @param n_train Maximum number of unique pairs to sample from the
#'   training set. Defaults to `10000`. Set to `NULL` to return all
#'   possible training pairs. Ignored when `prop` is `NULL`, in which
#'   case it limits the overall sample.
#' @param n_test Maximum number of unique pairs to sample from the test
#'   set. Defaults to `5000`. Set to `NULL` to return all possible test
#'   pairs. Only used when `prop` is supplied.
#' @param prop Optional proportion of documents assigned to the training
#'   set (e.g. `0.8`). When supplied, a `split` column is added to the
#'   result and `doc_id_a`/`doc_id_b` index into the full `documents`
#'   vector so the same embedding matrix can be used for both fitting
#'   and validation.
#' @param seed Optional integer random seed for reproducibility.
#'
#' @return A tibble with columns `doc_id_a`, `doc_id_b`, `text_a`, and
#'   `text_b`. `doc_id_a` and `doc_id_b` are integer row indices into
#'   `documents`. When `prop` is supplied, an additional `split` column
#'   contains `"train"` or `"test"`.
#'
#' @export
#'
#' @examples
#' docs <- c("The quick brown fox", "A lazy dog", "Hello world", "Foo bar")
#' # All unique pairs
#' generate_comparisons(docs, n_train = NULL)
#' # With an 80/20 train/test split, default sample sizes
#' generate_comparisons(docs, prop = 0.8, seed = 1)
generate_comparisons <- function(documents,
                                 n_train = 10000,
                                 n_test  = 5000,
                                 prop    = NULL,
                                 seed    = NULL) {
  if (!is.null(seed)) set.seed(seed)

  n_docs <- length(documents)
  if (n_docs < 2) stop("`documents` must contain at least 2 elements.")

  # Helper: generate all within-group pairs; indices are into `documents`
  all_pairs <- function(idx) {
    k <- length(idx)
    if (k < 2) return(list(a = integer(0), b = integer(0)))
    pos <- which(upper.tri(matrix(0L, k, k)), arr.ind = TRUE)
    list(a = idx[pos[, 1]], b = idx[pos[, 2]])
  }

  # Helper: sample up to n rows from a pair list
  sample_pairs <- function(pairs, n, label) {
    n_possible <- length(pairs$a)
    if (is.null(n) || n >= n_possible) {
      if (!is.null(n) && n > n_possible) {
        message(
          "`n_", label, "` (", n, ") exceeds the number of unique ", label,
          " pairs (", n_possible, "). Using all ", n_possible, "."
        )
      }
      return(pairs)
    }
    keep <- sample(n_possible, n)
    list(a = pairs$a[keep], b = pairs$b[keep])
  }

  if (!is.null(prop)) {
    # --- Split mode ---
    train_idx <- sort(sample(n_docs, floor(prop * n_docs)))
    test_idx  <- setdiff(seq_len(n_docs), train_idx)

    tr <- sample_pairs(all_pairs(train_idx), n_train, "train")
    te <- sample_pairs(all_pairs(test_idx),  n_test,  "test")

    ids_a  <- c(tr$a, te$a)
    ids_b  <- c(tr$b, te$b)
    splits <- c(rep("train", length(tr$a)), rep("test", length(te$a)))

    tibble::tibble(
      doc_id_a = ids_a,
      doc_id_b = ids_b,
      text_a   = documents[ids_a],
      text_b   = documents[ids_b],
      split    = splits
    )
  } else {
    # --- No-split mode ---
    n_possible <- choose(n_docs, 2)

    if (is.null(n_train)) {
      idx   <- which(upper.tri(matrix(0L, n_docs, n_docs)), arr.ind = TRUE)
      ids_a <- idx[, 1]
      ids_b <- idx[, 2]
    } else {
      if (n_train > n_possible) {
        message(
          "`n_train` (", n_train, ") exceeds the number of unique pairs (",
          n_possible, "). Using all ", n_possible, "."
        )
        idx   <- which(upper.tri(matrix(0L, n_docs, n_docs)), arr.ind = TRUE)
        ids_a <- idx[, 1]
        ids_b <- idx[, 2]
      } else {
        # Rejection sampling avoids materialising the full pair matrix
        ids_a   <- integer(n_train)
        ids_b   <- integer(n_train)
        n_found <- 0L
        seen    <- new.env(hash = TRUE, parent = emptyenv(), size = n_train)

        while (n_found < n_train) {
          batch <- max(n_train - n_found, 100L) * 2L
          a <- sample.int(n_docs, batch, replace = TRUE)
          b <- sample.int(n_docs, batch, replace = TRUE)
          keep <- a != b
          a <- a[keep]; b <- b[keep]
          swap <- a > b
          tmp <- a[swap]; a[swap] <- b[swap]; b[swap] <- tmp
          for (k in seq_along(a)) {
            if (n_found >= n_train) break
            key <- paste0(a[k], "_", b[k])
            if (!exists(key, envir = seen, inherits = FALSE)) {
              n_found <- n_found + 1L
              ids_a[n_found] <- a[k]
              ids_b[n_found] <- b[k]
              assign(key, TRUE, envir = seen)
            }
          }
        }
      }
    }

    tibble::tibble(
      doc_id_a = ids_a,
      doc_id_b = ids_b,
      text_a   = documents[ids_a],
      text_b   = documents[ids_b]
    )
  }
}
