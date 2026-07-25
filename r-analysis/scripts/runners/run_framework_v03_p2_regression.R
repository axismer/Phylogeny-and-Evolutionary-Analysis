# =============================================================================
# run_framework_v03_p2_regression.R — Framework v0.3 P2 Core IO
#
# 覆盖：
#   - FASTA tip  parity（count / set / order；core vs deprecated）
#   - virus/bacteria valid + IO 错误路径
#
# 用法：Rscript scripts/runners/run_framework_v03_p2_regression.R
# =============================================================================

args_full <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args_full, value = TRUE)
if (length(file_arg) < 1) stop("请用 Rscript 运行", call. = FALSE)
this_dir <- dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/"))
root <- normalizePath(file.path(this_dir, "..", ".."), winslash = "/")
runner <- file.path(root, "runners", "run_analysis.R")
out_root <- file.path(root, "output", "tasks", "framework_v03_p2_regression")
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

prep <- file.path(root, "scripts", "prep", "prepare_virus_regression_fixtures.R")
if (file.exists(prep)) {
  suppressWarnings(system2("Rscript", shQuote(prep), stdout = TRUE, stderr = TRUE))
}

# Load error_codes + fasta_io for tip parity (no full strategy)
source(file.path(root, "core", "error_codes.R"), local = FALSE)
source(file.path(root, "core", "io", "fasta_io.R"), local = FALSE)
source(file.path(root, "core", "io", "metadata_io.R"), local = FALSE)

`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1 && is.na(a))) b else a
}

# Legacy parser copy — must stay byte-logic identical to pre-P2 strategy
.read_fasta_records_legacy_copy <- function(fasta_path) {
  lines <- readLines(fasta_path, warn = FALSE, encoding = "UTF-8")
  ids <- character()
  seqs <- character()
  cur_id <- NULL
  cur <- character()
  flush <- function() {
    if (is.null(cur_id)) return()
    ids <<- c(ids, cur_id)
    seqs <<- c(seqs, toupper(paste(cur, collapse = "")))
  }
  for (ln in lines) {
    if (!nzchar(trimws(ln))) next
    if (startsWith(ln, ">")) {
      flush()
      cur_id <- sub("^>\\s*", "", ln)
      cur_id <- strsplit(cur_id, "\\s+")[[1]][[1]]
      cur <- character()
    } else {
      cur <- c(cur, gsub("\\s+", "", ln))
    }
  }
  flush()
  list(ids = ids, seqs = seqs)
}

assert_fasta_parity <- function(fasta_path, case_id) {
  notes <- character()
  ok <- TRUE
  core <- read_fasta(fasta_path)
  legacy <- .read_fasta_records_legacy_copy(fasta_path)

  if (!identical(length(core$ids), length(legacy$ids))) {
    ok <- FALSE
    notes <- c(notes, paste0(
      "sequence_count 不一致 core=", length(core$ids),
      " legacy=", length(legacy$ids)
    ))
  }
  if (!identical(sort(core$ids), sort(legacy$ids))) {
    ok <- FALSE
    notes <- c(notes, "tip id 集合不一致")
  }
  if (!identical(core$ids, legacy$ids)) {
    ok <- FALSE
    notes <- c(notes, "tip 顺序不一致")
  }
  if (!identical(core$seqs, legacy$seqs)) {
    ok <- FALSE
    notes <- c(notes, "序列内容不一致")
  }

  # metadata match: tip ids must be unique for matching semantics
  if (anyDuplicated(core$ids)) {
    ok <- FALSE
    notes <- c(notes, "tip id 有重复（影响 metadata 匹配语义）")
  }

  list(
    case_id = case_id,
    ok = ok,
    exit_code = if (ok) 0L else 1L,
    status = if (ok) "parity_ok" else "parity_fail",
    error_code = NA_character_,
    error_message = "",
    notes = if (length(notes)) paste(notes, collapse = " | ") else paste0(
      "PASS tip_count=", length(core$ids)
    ),
    tip_count = length(core$ids)
  )
}

read_result <- function(output_dir) {
  path <- file.path(output_dir, "analysis_result.json")
  if (!file.exists(path)) return(NULL)
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

run_case <- function(case_id, type, fasta, metadata = NULL,
                     expect_exit, expect_status, expect_error_code = NULL,
                     forbid_error_code = FALSE, error_substr = NULL) {
  out_dir <- file.path(out_root, case_id)
  if (dir.exists(out_dir)) unlink(out_dir, recursive = TRUE, force = TRUE)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  args <- c(shQuote(runner), "--type", type, "--fasta", shQuote(fasta),
            "--output", shQuote(out_dir))
  if (!is.null(metadata) && nzchar(metadata)) {
    args <- c(args, "--metadata", shQuote(metadata))
  }

  message("---- ", case_id, " ----")
  log <- suppressWarnings(system2("Rscript", args = args, stdout = TRUE, stderr = TRUE))
  exit_code <- attr(log, "status")
  if (is.null(exit_code)) exit_code <- 0L
  exit_code <- as.integer(exit_code)

  result <- read_result(out_dir)
  notes <- character()
  ok <- TRUE

  if (exit_code != as.integer(expect_exit)) {
    ok <- FALSE
    notes <- c(notes, paste0("exit 期望 ", expect_exit, " 实际 ", exit_code))
  }
  actual_status <- if (is.null(result)) "<missing>" else as.character(result$status)
  if (!actual_status %in% expect_status) {
    ok <- FALSE
    notes <- c(notes, paste0(
      "status 期望 ", paste(expect_status, collapse = "|"),
      " 实际 ", actual_status
    ))
  }
  if (is.null(result)) {
    ok <- FALSE
    notes <- c(notes, "analysis_result.json 缺失")
  } else {
    has_code <- "error_code" %in% names(result)
    if (isTRUE(forbid_error_code) && has_code) {
      ok <- FALSE
      notes <- c(notes, "success/partial 不应存在 error_code")
    }
    if (!is.null(expect_error_code)) {
      if (!has_code) {
        ok <- FALSE
        notes <- c(notes, "缺少 error_code")
      } else if (!identical(as.character(result$error_code), expect_error_code)) {
        ok <- FALSE
        notes <- c(notes, paste0(
          "error_code 期望 ", expect_error_code,
          " 实际 ", result$error_code
        ))
      }
    }
    if (!is.null(error_substr)) {
      msg <- as.character(result$error_message %||% "")
      if (!grepl(error_substr, msg, fixed = TRUE) &&
          !grepl(error_substr, msg, perl = TRUE)) {
        ok <- FALSE
        notes <- c(notes, paste0("error_message 未包含: ", error_substr))
      }
    }
  }

  list(
    case_id = case_id,
    ok = ok,
    exit_code = exit_code,
    status = actual_status,
    error_code = if (is.null(result) || is.null(result$error_code)) {
      NA_character_
    } else {
      as.character(result$error_code)
    },
    error_message = if (is.null(result)) "" else as.character(result$error_message %||% ""),
    notes = if (length(notes)) paste(notes, collapse = " | ") else "PASS"
  )
}

# --- tip parity (pre-pipeline) ---
virus_fasta <- file.path(root, "test-data", "virus", "valid", "sequences.fasta")
bacteria_fasta <- file.path(root, "test-data", "bacteria", "valid", "valid.fasta")

parity_results <- list(
  assert_fasta_parity(virus_fasta, "fasta_parity_virus_valid"),
  assert_fasta_parity(bacteria_fasta, "fasta_parity_bacteria_valid")
)

# metadata read parity: core read_metadata vs utils::read.csv
meta_parity_ok <- TRUE
meta_parity_notes <- "PASS"
virus_meta <- file.path(root, "test-data", "virus", "valid", "metadata.csv")
bacteria_meta <- file.path(root, "test-data", "bacteria", "valid", "metadata.csv")
for (mp in c(virus_meta, bacteria_meta)) {
  a <- read_metadata(mp)
  b <- utils::read.csv(mp, stringsAsFactors = FALSE, check.names = FALSE)
  if (!identical(names(a), names(b)) || !identical(nrow(a), nrow(b)) ||
      !identical(as.character(a[[1]]), as.character(b[[1]]))) {
    meta_parity_ok <- FALSE
    meta_parity_notes <- paste0("metadata 读取不一致: ", basename(dirname(mp)))
    break
  }
}
parity_results[[length(parity_results) + 1L]] <- list(
  case_id = "metadata_read_parity",
  ok = meta_parity_ok,
  exit_code = if (meta_parity_ok) 0L else 1L,
  status = if (meta_parity_ok) "parity_ok" else "parity_fail",
  error_code = NA_character_,
  error_message = "",
  notes = meta_parity_notes
)

missing_fasta <- file.path(out_root, "_missing_input.fasta")
if (file.exists(missing_fasta)) unlink(missing_fasta)

cases <- list(
  list(
    case_id = "virus_valid",
    type = "virus",
    fasta = virus_fasta,
    metadata = virus_meta,
    expect_exit = 0L,
    expect_status = c("success", "partial"),
    forbid_error_code = TRUE
  ),
  list(
    case_id = "virus_bad_fasta",
    type = "virus",
    fasta = file.path(root, "test-data", "virus", "invalid_fasta", "bad.fasta"),
    metadata = NULL,
    expect_exit = 1L,
    expect_status = "error",
    expect_error_code = "EMPTY_FASTA",
    error_substr = "FASTA"
  ),
  list(
    case_id = "virus_missing_metadata",
    type = "virus",
    fasta = virus_fasta,
    metadata = file.path(out_root, "_no_such_metadata.csv"),
    expect_exit = 1L,
    expect_status = "error",
    expect_error_code = "METADATA_FILE_NOT_FOUND"
  ),
  list(
    case_id = "bacteria_valid",
    type = "bacteria",
    fasta = bacteria_fasta,
    metadata = bacteria_meta,
    expect_exit = 0L,
    expect_status = c("success", "partial"),
    forbid_error_code = TRUE
  ),
  list(
    case_id = "bacteria_bad_metadata",
    type = "bacteria",
    fasta = file.path(root, "test-data", "bacteria", "missing_fields", "sequences.fasta"),
    metadata = file.path(root, "test-data", "bacteria", "missing_fields", "metadata.csv"),
    expect_exit = 1L,
    expect_status = "error",
    expect_error_code = "MISSING_METADATA_FIELDS"
  ),
  list(
    case_id = "bacteria_missing_fasta",
    type = "bacteria",
    fasta = missing_fasta,
    metadata = bacteria_meta,
    expect_exit = 1L,
    expect_status = "error",
    expect_error_code = "EMPTY_FASTA"
  )
)

pipeline_results <- lapply(cases, function(c) do.call(run_case, c))

# Post-valid: metadata match consistency via tip_validator if available
tip_match_ok <- TRUE
tip_match_notes <- "SKIPPED"
source(file.path(root, "core", "tip_validator.R"), local = FALSE)
virus_out <- file.path(out_root, "virus_valid")
bact_out <- file.path(out_root, "bacteria_valid")
if (file.exists(file.path(virus_out, "tree.nwk")) &&
    file.exists(file.path(virus_out, "metadata.csv"))) {
  vmeta <- utils::read.csv(
    file.path(virus_out, "metadata.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  vtips <- assert_tip_match(
    file.path(virus_out, "tree.nwk"),
    vmeta,
    id_column = "label"
  )
  bmeta <- utils::read.csv(
    file.path(bact_out, "metadata.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  btips <- assert_tip_match(
    file.path(bact_out, "tree.nwk"),
    bmeta,
    id_column = "label"
  )
  if (!isTRUE(vtips$ok) || !isTRUE(btips$ok)) {
    tip_match_ok <- FALSE
    tip_match_notes <- paste0(
      "virus_ok=", isTRUE(vtips$ok),
      " bacteria_ok=", isTRUE(btips$ok)
    )
  } else {
    tip_match_notes <- paste0(
      "PASS virus_matched=", vtips$matched,
      " bacteria_matched=", btips$matched
    )
  }
} else {
  tip_match_ok <- FALSE
  tip_match_notes <- "valid 输出缺少 tree.nwk/metadata.csv"
}

parity_results[[length(parity_results) + 1L]] <- list(
  case_id = "metadata_tip_match_valid",
  ok = tip_match_ok,
  exit_code = if (tip_match_ok) 0L else 1L,
  status = if (tip_match_ok) "parity_ok" else "parity_fail",
  error_code = NA_character_,
  error_message = "",
  notes = tip_match_notes
)

results <- c(parity_results, pipeline_results)

summary_path <- file.path(out_root, "summary.json")
payload <- list(
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  framework = "v0.3-p2",
  cases = lapply(results, function(r) {
    list(
      case_id = r$case_id,
      ok = r$ok,
      exit_code = r$exit_code,
      status = r$status,
      error_code = r$error_code,
      error_message = r$error_message,
      notes = r$notes
    )
  })
)
jsonlite::write_json(payload, summary_path, auto_unbox = TRUE, pretty = TRUE)

n_pass <- sum(vapply(results, function(r) isTRUE(r$ok), logical(1)))
n_fail <- length(results) - n_pass
message("======== Framework v0.3 P2 regression ========")
for (r in results) {
  message(sprintf(
    "[%s] %s | exit=%s status=%s code=%s | %s",
    if (isTRUE(r$ok)) "PASS" else "FAIL",
    r$case_id, r$exit_code, r$status,
    if (is.na(r$error_code)) "<none>" else r$error_code,
    r$notes
  ))
}
message(sprintf("Passed %d / %d  (summary: %s)", n_pass, length(results), summary_path))
quit(save = "no", status = if (n_fail == 0) 0 else 1)
