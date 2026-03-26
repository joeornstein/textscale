#' Wisconsin political ads (2008)
#'
#' A dataset of 935 Wisconsin congressional campaign advertisements from the
#' 2008 election cycle. Ad texts and pairwise annotations are drawn from
#' Carlson & Montgomery (2017); five-point tone codes are from the Wisconsin
#' Advertising Project (WiscAds). The `score` column contains textscale
#' negativity scores derived from the pairwise comparisons in
#' [cm_comparisons].
#'
#' @format A tibble with 935 rows and 10 columns:
#' \describe{
#'   \item{text}{Full text of the advertisement.}
#'   \item{candidate}{Coded candidate identifier (factor).}
#'   \item{state}{Two-letter state abbreviation. Empty string for ads with
#'     no state on record.}
#'   \item{tone}{Numeric tone code from the Wisconsin Advertising Project
#'     (1 = Promoting, 2 = Mostly promoting, 3 = Contrasting,
#'     4 = Mostly attacking, 5 = Attacking). `NA` for ads without a tone
#'     code.}
#'   \item{alphas}{Continuous negativity score from the SentimentIt model
#'     in Carlson & Montgomery (2017).}
#'   \item{score}{textscale negativity score derived from the pairwise
#'     comparisons in [cm_comparisons].}
#'   \item{score_lower}{Lower bound of the 95% confidence interval for
#'     `score`.}
#'   \item{score_upper}{Upper bound of the 95% confidence interval for
#'     `score`.}
#'   \item{split}{Whether the document was in the `"Train Set"` or
#'     `"Test Set"` split used to validate the model.}
#'   \item{tone_label}{Factor version of `tone` with descriptive labels.}
#' }
#'
#' @seealso [cm_comparisons], [ad_tone_validation]
#'
#' @source Carlson, T. N., & Montgomery, J. M. (2017). A pairwise comparison
#'   framework for fast, flexible, and reliable human coding of political
#'   texts. *American Political Science Review*, 111(4), 835–843.
#'   \doi{10.1017/S0003055417000302}
"ad_tone"


#' Validation results for the ad-tone model
#'
#' A `textscale_validation` object produced by [validate_model()] for the
#' ad-tone example. Contains test-set accuracy and calibration metrics for
#' the textscale model fit to the Carlson & Montgomery (2017) Wisconsin ads
#' using the human pairwise annotations in [cm_comparisons].
#'
#' @format A `textscale_validation` object (a list) with three elements:
#' \describe{
#'   \item{metrics}{A one-row tibble with columns `n_pairs`, `n_correct`,
#'     `accuracy`, and `ici`.}
#'   \item{cal_df}{A data frame with columns `prob` (predicted probability)
#'     and `result` (observed outcome) for each test comparison. Used to
#'     construct the calibration plot.}
#'   \item{ici}{Integrated Calibration Index (scalar).}
#' }
#'
#' @seealso [validate_model()], [ad_tone], [cm_comparisons]
"ad_tone_validation"


#' Pairwise annotations from Carlson & Montgomery (2017)
#'
#' Human-annotated pairwise comparisons from the Wisconsin congressional ads
#' study of Carlson & Montgomery (2017). Each row records which of two ads
#' was judged more negative by human annotators. Document indices reference
#' row positions in [ad_tone].
#'
#' @format A tibble with 9,528 rows and 4 columns:
#' \describe{
#'   \item{doc_id_a}{Integer row index of the first ad in [ad_tone].}
#'   \item{doc_id_b}{Integer row index of the second ad in [ad_tone].}
#'   \item{winner}{`"A"` if the first ad was judged more negative;
#'     `"B"` if the second ad was.}
#'   \item{split}{Whether the pair belongs to the `"train"` or `"test"`
#'     split used to validate the textscale model in [ad_tone_validation].}
#' }
#'
#' @seealso [ad_tone], [ad_tone_validation]
#'
#' @source Carlson, T. N., & Montgomery, J. M. (2017). A pairwise comparison
#'   framework for fast, flexible, and reliable human coding of political
#'   texts. *American Political Science Review*, 111(4), 835–843.
#'   \doi{10.1017/S0003055417000302}
"cm_comparisons"
