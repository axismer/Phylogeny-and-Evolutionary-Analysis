# =============================================================================
# run_framework_v03_p4_regression.R — Framework v0.3 P4 稳定化回归
#
# 覆盖：plugin discovery / contract / unknown / duplicate / invalid /
#       virus + bacteria pipeline
#
# 用法：Rscript scripts/runners/run_framework_v03_p4_regression.R
# =============================================================================

args_full <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args_full, value = TRUE)
if (length(file_arg) < 1) stop("请用 Rscript 运行", call. = FALSE)
this_dir <- dirname(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/"))
root <- normalizePath(file.path(this_dir, "..", ".."), winslash = "/")
runner <- file.path(root, "runners", "run_analysis.R")
out_root <- file.path(root, "output", "tasks", "framework_v03_p4_regression")
dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

prep <- file.path(root, "scripts", "prep", "prepare_virus_regression_fixtures.R")
if (file.exists(prep)) {
  suppressWarnings(system2("Rscript", shQuote(prep), stdout = TRUE, stderr = TRUE))
}

`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1 && is.na(a))) b else a
}

read_result <- function(output_dir) {
  path <- file.path(output_dir, "analysis_result.json")
  if (!file.exists(path)) return(NULL)
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

run_case <- function(case_id, type, fasta, metadata = NULL,
                     expect_exit, expect_status, expect_error_code = NULL,
                     forbid_error_code = FALSE) {
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
    notes = if (length(notes)) paste(notes, collapse = " | ") else "PASS"
  )
}

# --- in-process: discovery + contract + duplicate + invalid ---
source(file.path(root, "strategies", "strategy_registry.R"), local = FALSE)
dirs <- source_framework_core()
discover_and_register_plugins(dirs, reset = TRUE)

registered <- list_registered_strategies()
need <- c("virus", "bacteria", "archaea", "eukaryote")
discovery_ok <- all(need %in% registered)

contract_ok <- TRUE
contract_notes <- character()
for (tp in need) {
  entry <- get_registered_plugin(tp)
  if (is.null(entry)) {
    contract_ok <- FALSE
    contract_notes <- c(contract_notes, paste0(tp, "=missing"))
    next
  }
  tryCatch(
    validate_plugin_contract(entry$env, plugin_path = entry$plugin_path),
    error = function(e) {
      contract_ok <<- FALSE
      contract_notes <<- c(contract_notes, paste0(tp, ":", conditionMessage(e)))
    }
  )
}
if (!length(contract_notes)) contract_notes <- "PASS all four plugins"

# invalid plugin
invalid_ok <- FALSE
invalid_code <- NA_character_
bad_env <- new.env(parent = emptyenv())
bad_env$get_organism_type <- function() "broken"
tryCatch(
  {
    validate_plugin_contract(bad_env, plugin_path = "p4_invalid")
  },
  error = function(e) {
    invalid_code <<- extract_error_code(e, default = "")
    if (identical(invalid_code, "PLUGIN_CONTRACT_INVALID")) {
      invalid_ok <<- TRUE
    }
  }
)

# duplicate
dup_ok <- FALSE
dup_code <- NA_character_
dup_env <- new.env(parent = globalenv())
dup_env$get_organism_type <- function() "virus"
dup_env$get_status <- function() "production"
dup_env$get_metadata_schema <- function() {
  list(organism_type = "virus", extra_columns = character())
}
dup_env$get_default_config <- function() {
  list(tree = list(), distance = list(), visualization = list())
}
dup_env$get_strategy <- function() stop("noop")
tryCatch(
  {
    validate_plugin_contract(dup_env, plugin_path = "p4_dup")
    register_plugin_manifest(
      build_plugin_manifest(dup_env, "p4_dup/plugin.R"),
      overwrite = FALSE
    )
  },
  error = function(e) {
    dup_code <<- extract_error_code(e, default = "")
    if (identical(dup_code, "PLUGIN_DUPLICATE_TYPE")) {
      dup_ok <<- TRUE
    }
  }
)

unit_results <- list(
  list(
    case_id = "all_plugin_discovery",
    ok = discovery_ok,
    exit_code = if (discovery_ok) 0L else 1L,
    status = if (discovery_ok) "ok" else "fail",
    error_code = NA_character_,
    notes = if (discovery_ok) {
      paste0("PASS registered=", paste(registered, collapse = ","))
    } else {
      paste0("缺少: ", paste(setdiff(need, registered), collapse = ","))
    }
  ),
  list(
    case_id = "all_contract_valid",
    ok = contract_ok,
    exit_code = if (contract_ok) 0L else 1L,
    status = if (contract_ok) "ok" else "fail",
    error_code = NA_character_,
    notes = paste(contract_notes, collapse = " | ")
  ),
  list(
    case_id = "invalid_plugin",
    ok = invalid_ok,
    exit_code = if (invalid_ok) 0L else 1L,
    status = if (invalid_ok) "ok" else "fail",
    error_code = invalid_code,
    notes = if (invalid_ok) "PASS PLUGIN_CONTRACT_INVALID" else paste0("code=", invalid_code)
  ),
  list(
    case_id = "duplicate_plugin",
    ok = dup_ok,
    exit_code = if (dup_ok) 0L else 1L,
    status = if (dup_ok) "ok" else "fail",
    error_code = dup_code,
    notes = if (dup_ok) "PASS PLUGIN_DUPLICATE_TYPE" else paste0("code=", dup_code)
  )
)

virus_fasta <- file.path(root, "test-data", "virus", "valid", "sequences.fasta")
virus_meta <- file.path(root, "test-data", "virus", "valid", "metadata.csv")
bact_fasta <- file.path(root, "test-data", "bacteria", "valid", "valid.fasta")
bact_meta <- file.path(root, "test-data", "bacteria", "valid", "metadata.csv")

pipeline_results <- lapply(
  list(
    list(
      case_id = "virus_pipeline",
      type = "virus",
      fasta = virus_fasta,
      metadata = virus_meta,
      expect_exit = 0L,
      expect_status = c("success", "partial"),
      forbid_error_code = TRUE
    ),
    list(
      case_id = "bacteria_pipeline",
      type = "bacteria",
      fasta = bact_fasta,
      metadata = bact_meta,
      expect_exit = 0L,
      expect_status = c("success", "partial"),
      forbid_error_code = TRUE
    ),
    list(
      case_id = "unknown_type",
      type = "fungi_unknown_xyz",
      fasta = virus_fasta,
      metadata = NULL,
      expect_exit = 2L,
      expect_status = "not_implemented",
      expect_error_code = "UNSUPPORTED_ORGANISM"
    )
  ),
  function(c) do.call(run_case, c)
)

results <- c(unit_results, pipeline_results)

summary_path <- file.path(out_root, "summary.json")
jsonlite::write_json(
  list(
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    framework = "v0.3-p4",
    cases = lapply(results, function(r) {
      list(
        case_id = r$case_id,
        ok = r$ok,
        exit_code = r$exit_code,
        status = r$status,
        error_code = r$error_code,
        notes = r$notes
      )
    })
  ),
  summary_path,
  auto_unbox = TRUE,
  pretty = TRUE
)

n_pass <- sum(vapply(results, function(r) isTRUE(r$ok), logical(1)))
n_fail <- length(results) - n_pass
message("======== Framework v0.3 P4 regression ========")
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
