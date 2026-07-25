# =============================================================================
# run_framework_regression.R — Multi-Organism Framework v0.2 回归测试
#
# 覆盖：
#   virus:   valid | invalid_fasta | metadata_mismatch |
#            empty | illegal_dna | too_few
#   bacteria: valid | invalid_metadata | tip_mismatch |
#             empty | illegal_dna | too_few
#   archaea: not_implemented
#
# 用法（在 r-analysis/ 下）：
#   Rscript scripts/runners/run_framework_regression.R
#
# 退出码：0 全部通过；1 有失败
# =============================================================================

args_full <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args_full, value = TRUE)
if (length(file_arg) < 1) {
  stop("请用 Rscript 运行本脚本", call. = FALSE)
}
this_dir <- dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/"))
root <- normalizePath(file.path(this_dir, "..", ".."), winslash = "/")
runner <- file.path(root, "runners", "run_analysis.R")
out_root <- file.path(root, "output", "tasks", "framework_v02_regression")

REQUIRED_FIELDS <- c(
  "status", "organism_type", "input", "tree",
  "visualization", "metadata", "statistics", "error_message"
)
ALLOWED_STATUS <- c("success", "partial", "error", "not_implemented")

dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

prep <- file.path(root, "scripts", "prep", "prepare_virus_regression_fixtures.R")
if (file.exists(prep)) {
  system2("Rscript", shQuote(prep), stdout = TRUE, stderr = TRUE)
}

read_result <- function(output_dir) {
  path <- file.path(output_dir, "analysis_result.json")
  if (!file.exists(path)) return(NULL)
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    stop("需要 jsonlite", call. = FALSE)
  }
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1 && is.na(a))) b else a
}

assert_contract_shape <- function(result, case_id) {
  errs <- character()
  if (is.null(result)) {
    return("analysis_result.json 缺失")
  }
  missing <- setdiff(REQUIRED_FIELDS, names(result))
  if (length(missing)) {
    errs <- c(errs, paste0("缺少字段: ", paste(missing, collapse = ", ")))
  }
  st <- as.character(result$status %||% "")
  if (!st %in% ALLOWED_STATUS) {
    errs <- c(errs, paste0("非法 status: ", st))
  }
  stats <- result$statistics
  if (is.null(stats)) {
    errs <- c(errs, "statistics 为 null")
  } else if (is.data.frame(stats)) {
    errs <- c(errs, "statistics 不应为 data.frame")
  } else if (is.atomic(stats) && length(stats) == 0) {
    errs <- c(errs, "statistics 为 JSON 数组 []（应为 object {}）")
  } else if (is.list(stats) && length(stats) == 0 && is.null(names(stats))) {
    errs <- c(errs, "statistics 为 JSON 数组 []（应为 object {}）")
  }
  if (identical(st, "error")) {
    msg <- as.character(result$error_message %||% "")
    if (!nzchar(msg)) {
      errs <- c(errs, "status=error 但 error_message 为空")
    }
  }
  if (length(errs)) paste(errs, collapse = "; ") else NULL
}

run_case <- function(case_id,
                     type,
                     fasta,
                     metadata = NULL,
                     expect_exit,
                     expect_status,
                     error_substr = NULL) {
  out_dir <- file.path(out_root, case_id)
  if (dir.exists(out_dir)) unlink(out_dir, recursive = TRUE, force = TRUE)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  args <- c(
    shQuote(runner),
    "--type", type,
    "--fasta", shQuote(fasta),
    "--output", shQuote(out_dir)
  )
  if (!is.null(metadata) && nzchar(metadata)) {
    args <- c(args, "--metadata", shQuote(metadata))
  }

  message("---- ", case_id, " ----")
  log <- suppressWarnings(system2("Rscript", args = args, stdout = TRUE, stderr = TRUE))
  exit_code <- attr(log, "status")
  if (is.null(exit_code)) exit_code <- 0L
  exit_code <- as.integer(exit_code)

  result <- read_result(out_dir)
  shape_err <- assert_contract_shape(result, case_id)

  ok <- TRUE
  notes <- character()
  if (exit_code != as.integer(expect_exit)) {
    ok <- FALSE
    notes <- c(notes, paste0("exit 期望 ", expect_exit, " 实际 ", exit_code))
  }
  actual_status <- if (is.null(result)) "<missing>" else as.character(result$status)
  expect_statuses <- if (length(expect_status) > 1) expect_status else expect_status
  if (!actual_status %in% expect_statuses) {
    ok <- FALSE
    notes <- c(notes, paste0(
      "status 期望 ", paste(expect_statuses, collapse = "|"),
      " 实际 ", actual_status
    ))
  }
  if (!is.null(shape_err)) {
    ok <- FALSE
    notes <- c(notes, shape_err)
  }
  if (!is.null(error_substr) && !is.null(result)) {
    msg <- as.character(result$error_message %||% "")
    if (!grepl(error_substr, msg, fixed = TRUE) && !grepl(error_substr, msg, perl = TRUE)) {
      ok <- FALSE
      notes <- c(notes, paste0("error_message 未包含: ", error_substr))
    }
  }

  list(
    case_id = case_id,
    ok = ok,
    exit_code = exit_code,
    status = actual_status,
    error_message = if (is.null(result)) "" else as.character(result$error_message %||% ""),
    notes = if (length(notes)) paste(notes, collapse = " | ") else "PASS"
  )
}

cases <- list(
  # --- virus core ---
  list(
    case_id = "virus_valid",
    type = "virus",
    fasta = file.path(root, "test-data", "virus", "valid", "sequences.fasta"),
    metadata = file.path(root, "test-data", "virus", "valid", "metadata.csv"),
    expect_exit = 0L,
    expect_status = c("success", "partial"),
    error_substr = NULL
  ),
  list(
    case_id = "virus_invalid_fasta",
    type = "virus",
    fasta = file.path(root, "test-data", "virus", "invalid_fasta", "bad.fasta"),
    metadata = NULL,
    expect_exit = 1L,
    expect_status = "error",
    error_substr = "FASTA"
  ),
  list(
    case_id = "virus_metadata_mismatch",
    type = "virus",
    fasta = file.path(root, "test-data", "virus", "metadata_mismatch", "sequences.fasta"),
    metadata = file.path(root, "test-data", "virus", "metadata_mismatch", "metadata.csv"),
    expect_exit = 1L,
    expect_status = "error",
    error_substr = "不匹配"
  ),
  list(
    case_id = "virus_empty",
    type = "virus",
    fasta = file.path(root, "test-data", "virus", "empty", "empty.fasta"),
    metadata = NULL,
    expect_exit = 1L,
    expect_status = "error",
    error_substr = "FASTA"
  ),
  list(
    case_id = "virus_illegal_dna",
    type = "virus",
    fasta = file.path(root, "test-data", "virus", "illegal_dna", "sequences.fasta"),
    metadata = NULL,
    expect_exit = 1L,
    expect_status = "error",
    error_substr = "DNA"
  ),
  list(
    case_id = "virus_too_few",
    type = "virus",
    fasta = file.path(root, "test-data", "virus", "too_few", "sequences.fasta"),
    metadata = NULL,
    expect_exit = 1L,
    expect_status = "error",
    error_substr = "至少需要 3"
  ),
  # --- bacteria ---
  list(
    case_id = "bacteria_valid",
    type = "bacteria",
    fasta = file.path(root, "test-data", "bacteria", "valid", "valid.fasta"),
    metadata = file.path(root, "test-data", "bacteria", "valid", "metadata.csv"),
    expect_exit = 0L,
    expect_status = c("success", "partial"),
    error_substr = NULL
  ),
  list(
    case_id = "bacteria_invalid_metadata",
    type = "bacteria",
    fasta = file.path(root, "test-data", "bacteria", "missing_fields", "sequences.fasta"),
    metadata = file.path(root, "test-data", "bacteria", "missing_fields", "metadata.csv"),
    expect_exit = 1L,
    expect_status = "error",
    error_substr = "resistance"
  ),
  list(
    case_id = "bacteria_tip_mismatch",
    type = "bacteria",
    fasta = file.path(root, "test-data", "bacteria", "tip_mismatch", "sequences.fasta"),
    metadata = file.path(root, "test-data", "bacteria", "tip_mismatch", "metadata.csv"),
    expect_exit = 1L,
    expect_status = "error",
    error_substr = "不匹配"
  ),
  list(
    case_id = "bacteria_empty",
    type = "bacteria",
    fasta = file.path(root, "test-data", "bacteria", "empty", "empty.fasta"),
    metadata = file.path(root, "test-data", "bacteria", "empty", "metadata.csv"),
    expect_exit = 1L,
    expect_status = "error",
    error_substr = "至少需要 3"
  ),
  list(
    case_id = "bacteria_illegal_dna",
    type = "bacteria",
    fasta = file.path(root, "test-data", "bacteria", "illegal_dna", "sequences.fasta"),
    metadata = file.path(root, "test-data", "bacteria", "illegal_dna", "metadata.csv"),
    expect_exit = 1L,
    expect_status = "error",
    error_substr = "DNA"
  ),
  list(
    case_id = "bacteria_too_few",
    type = "bacteria",
    fasta = file.path(root, "test-data", "bacteria", "too_few", "sequences.fasta"),
    metadata = file.path(root, "test-data", "bacteria", "too_few", "metadata.csv"),
    expect_exit = 1L,
    expect_status = "error",
    error_substr = "至少需要 3"
  ),
  # --- not_implemented ---
  list(
    case_id = "archaea_not_implemented",
    type = "archaea",
    fasta = file.path(root, "test-data", "virus", "valid", "sequences.fasta"),
    metadata = NULL,
    expect_exit = 2L,
    expect_status = "not_implemented",
    error_substr = NULL
  )
)

results <- lapply(cases, function(c) {
  r <- do.call(run_case, c)
  if (r$exit_code == as.integer(c$expect_exit) &&
      r$status %in% c$expect_status) {
    shape <- assert_contract_shape(read_result(file.path(out_root, c$case_id)), c$case_id)
    if (is.null(shape) && isTRUE(r$ok)) {
      r$notes <- paste0("PASS (status=", r$status, ")")
    }
  }
  r
})

summary_path <- file.path(out_root, "summary.json")
payload <- list(
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  framework = "v0.2-hardening",
  contract = "docs/analysis_result_contract.md",
  cases = lapply(results, function(r) {
    list(
      case_id = r$case_id,
      ok = r$ok,
      exit_code = r$exit_code,
      status = r$status,
      error_message = r$error_message,
      notes = r$notes
    )
  })
)
if (requireNamespace("jsonlite", quietly = TRUE)) {
  jsonlite::write_json(payload, summary_path, auto_unbox = TRUE, pretty = TRUE)
}

n_pass <- sum(vapply(results, function(r) isTRUE(r$ok), logical(1)))
n_fail <- length(results) - n_pass
message("======== Framework v0.2 regression ========")
for (r in results) {
  message(sprintf(
    "[%s] %s | exit=%s status=%s | %s",
    if (isTRUE(r$ok)) "PASS" else "FAIL",
    r$case_id, r$exit_code, r$status, r$notes
  ))
}
message(sprintf("Passed %d / %d  (summary: %s)", n_pass, length(results), summary_path))

quit(save = "no", status = if (n_fail == 0) 0 else 1)
