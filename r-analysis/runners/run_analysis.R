# =============================================================================
# run_analysis.R — 多生物类型统一 CLI 入口
#
# 退出码：
#   0 = success|partial
#   1 = error
#   2 = not_implemented（含未知 organism / stub）
#
# v0.3 P1：未知 organism → not_implemented + UNSUPPORTED_ORGANISM + exit 2
# =============================================================================

parse_named_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  if (length(args) == 0) {
    return(list())
  }
  out <- list()
  i <- 1L
  while (i <= length(args)) {
    a <- args[[i]]
    if (!startsWith(a, "--")) {
      stop("无法解析参数: ", a, "（期望 --key value）", call. = FALSE)
    }
    key <- sub("^--", "", a)
    if (i == length(args) || startsWith(args[[i + 1L]], "--")) {
      out[[key]] <- TRUE
      i <- i + 1L
    } else {
      out[[key]] <- args[[i + 1L]]
      i <- i + 2L
    }
  }
  out
}

print_usage <- function() {
  registered <- character()
  if (exists("list_registered_strategies", mode = "function")) {
    registered <- tryCatch(list_registered_strategies(), error = function(...) character())
  }
  type_hint <- if (length(registered)) {
    paste(registered, collapse = "|")
  } else {
    "virus|bacteria|archaea|eukaryote"
  }
  message("用法:")
  message("  Rscript runners/run_analysis.R \\")
  message("    --type <", type_hint, "> \\")
  message("    --fasta <sequence.fasta> \\")
  message("    --output <output_dir> \\")
  message("    [--metadata <metadata.csv>] \\")
  message("    [--rscript <Rscript>] \\")
  message("    [--config <analysis_config.yaml>]")
}

load_yaml_config <- function(path) {
  if (is.null(path) || !nzchar(path) || !file.exists(path)) {
    return(list())
  }
  if (requireNamespace("yaml", quietly = TRUE)) {
    return(yaml::read_yaml(path))
  }
  message("[警告] 未安装 yaml 包，跳过配置文件: ", path)
  list()
}

resolve_runner_root <- function() {
  args_full <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args_full, value = TRUE)
  if (length(file_arg) > 0) {
    runner_dir <- dirname(normalizePath(sub("^--file=", "", file_arg[1])))
  } else {
    runner_dir <- normalizePath(getwd())
  }
  normalizePath(file.path(runner_dir, ".."), winslash = "/")
}

#' 写出 error JSON 兜底
write_runner_error_json <- function(output_dir,
                                    organism_type = "",
                                    error_message = "",
                                    error_code = "",
                                    input = "") {
  if (is.null(output_dir) || !nzchar(as.character(output_dir)[[1]])) {
    return(invisible(FALSE))
  }
  tryCatch(
    {
      if (!dir.exists(output_dir)) {
        dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
      }
      json_path <- file.path(output_dir, "analysis_result.json")
      if (file.exists(json_path) && requireNamespace("jsonlite", quietly = TRUE)) {
        prev <- tryCatch(jsonlite::fromJSON(json_path), error = function(...) NULL)
        if (!is.null(prev) && identical(as.character(prev$status), "error") &&
            !is.null(prev$error_code) && nzchar(as.character(prev$error_code)[[1]])) {
          return(invisible(TRUE))
        }
        if (!is.null(prev) && identical(as.character(prev$status), "not_implemented")) {
          return(invisible(TRUE))
        }
      }
      if (exists("write_error_analysis_result", mode = "function")) {
        write_error_analysis_result(
          organism_type = if (nzchar(organism_type)) organism_type else "unknown",
          output_dir = output_dir,
          error_message = error_message,
          error_code = error_code,
          input = input
        )
      } else if (requireNamespace("jsonlite", quietly = TRUE)) {
        payload <- list(
          status = "error",
          organism_type = if (nzchar(organism_type)) organism_type else "unknown",
          input = input,
          tree = "",
          visualization = "",
          metadata = "",
          statistics = structure(list(), names = character(0)),
          error_message = as.character(error_message)[[1]],
          error_code = as.character(error_code %||% "")[[1]],
          tree_file = ""
        )
        jsonlite::write_json(payload, json_path, auto_unbox = TRUE, pretty = TRUE)
      }
      invisible(TRUE)
    },
    error = function(...) invisible(FALSE)
  )
}

#' 未知 organism → not_implemented + exit 2（不改 registry）
write_runner_unsupported_organism <- function(output_dir,
                                              organism_type,
                                              input = "",
                                              detail = "") {
  if (is.null(output_dir) || !nzchar(as.character(output_dir)[[1]])) {
    return(invisible(FALSE))
  }
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }
  msg <- if (nzchar(detail)) {
    detail
  } else {
    paste0("Unsupported or unknown organism_type: ", organism_type)
  }
  if (exists("write_not_implemented_result", mode = "function")) {
    write_not_implemented_result(
      organism_type = organism_type,
      output_dir = output_dir,
      error_message = msg,
      input = input
    )
  } else if (requireNamespace("jsonlite", quietly = TRUE)) {
    payload <- list(
      status = "not_implemented",
      organism_type = if (nzchar(organism_type)) organism_type else "unknown",
      input = input,
      tree = "",
      visualization = "",
      metadata = "",
      statistics = structure(list(), names = character(0)),
      error_message = msg,
      error_code = "UNSUPPORTED_ORGANISM",
      tree_file = ""
    )
    jsonlite::write_json(
      payload,
      file.path(output_dir, "analysis_result.json"),
      auto_unbox = TRUE,
      pretty = TRUE
    )
  }
  invisible(TRUE)
}

is_unknown_organism_error <- function(msg) {
  grepl("未知\\s*--type|未知 --type|Unsupported or unknown organism", msg, perl = TRUE)
}

is_plugin_error <- function(msg, code = "") {
  if (nzchar(as.character(code)[[1]]) &&
      grepl("^PLUGIN_", as.character(code)[[1]])) {
    return(TRUE)
  }
  grepl(
    "PLUGIN_DUPLICATE_TYPE|PLUGIN_CONTRACT_INVALID|PLUGIN_LOAD_FAILED|PLUGIN_NOT_FOUND|duplicate plugin|plugin contract",
    msg,
    ignore.case = TRUE,
    perl = TRUE
  )
}

`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1 && is.na(a))) b else a
}

main <- function() {
  opts <- parse_named_args()
  if (isTRUE(opts$help) || isTRUE(opts$h)) {
    print_usage()
    quit(save = "no", status = 0)
  }

  type <- opts$type
  fasta <- opts$fasta
  output <- opts$output
  metadata <- opts$metadata
  rscript <- if (!is.null(opts$rscript)) opts$rscript else "Rscript"

  .runner_state <<- list(
    organism_type = if (is.null(type)) "" else as.character(type),
    output_dir = if (is.null(output)) "" else as.character(output),
    fasta = if (is.null(fasta)) "" else as.character(fasta),
    exit_hint = 1L
  )

  if (is.null(type) || is.null(fasta) || is.null(output)) {
    print_usage()
    stop("缺少必需参数: --type --fasta --output", call. = FALSE)
  }

  root <- resolve_runner_root()
  registry <- file.path(root, "strategies", "strategy_registry.R")
  if (!file.exists(registry)) {
    stop("找不到 strategy_registry.R: ", registry, call. = FALSE)
  }
  source(registry, local = FALSE)

  # P3：仅扫描 strategies/*/plugin.R（无 builtins 硬编码）
  dirs <- source_framework_core()
  tryCatch(
    discover_and_register_plugins(dirs, reset = TRUE),
    error = function(e) {
      msg <- conditionMessage(e)
      code <- if (exists("extract_error_code", mode = "function")) {
        extract_error_code(e, default = "PLUGIN_LOAD_FAILED")
      } else {
        "PLUGIN_LOAD_FAILED"
      }
      out_early <- if (!is.null(output) && nzchar(output)) {
        normalizePath(output, winslash = "/", mustWork = FALSE)
      } else {
        ""
      }
      if (nzchar(out_early)) {
        write_runner_error_json(
          output_dir = out_early,
          organism_type = if (is.null(type)) "" else type,
          error_message = msg,
          error_code = code,
          input = if (!is.null(fasta)) basename(fasta) else ""
        )
      }
      message("[run_analysis] plugin discovery failed: ", msg)
      quit(save = "no", status = 1)
    }
  )

  out_norm <- normalizePath(output, winslash = "/", mustWork = FALSE)
  input_base <- basename(fasta)
  .runner_state$output_dir <<- out_norm

  if (!tolower(type) %in% list_registered_strategies()) {
    write_runner_unsupported_organism(
      output_dir = out_norm,
      organism_type = type,
      input = input_base,
      detail = paste0(
        "未知 --type: ", type,
        "；已注册: ", paste(list_registered_strategies(), collapse = ", ")
      )
    )
    message("[run_analysis] status=not_implemented error_code=UNSUPPORTED_ORGANISM")
    quit(save = "no", status = 2)
  }

  config_path <- if (!is.null(opts$config)) {
    opts$config
  } else {
    file.path(root, "config", "analysis_config.yaml")
  }
  config <- load_yaml_config(config_path)

  strategy <- tryCatch(
    get_strategy(type),
    error = function(e) {
      msg <- conditionMessage(e)
      code <- if (exists("extract_error_code", mode = "function")) {
        extract_error_code(e, default = "")
      } else {
        ""
      }
      if (is_unknown_organism_error(msg)) {
        write_runner_unsupported_organism(
          output_dir = out_norm,
          organism_type = type,
          input = input_base,
          detail = msg
        )
        quit(save = "no", status = 2)
      }
      if (is_plugin_error(msg, code)) {
        write_runner_error_json(
          output_dir = out_norm,
          organism_type = type,
          error_message = msg,
          error_code = if (nzchar(code)) code else "PLUGIN_LOAD_FAILED",
          input = input_base
        )
        quit(save = "no", status = 1)
      }
      stop(e)
    }
  )

  ctx <- new_analysis_context(
    organism_type = type,
    fasta_path = normalizePath(fasta, winslash = "/", mustWork = FALSE),
    metadata_path = if (!is.null(metadata)) {
      normalizePath(metadata, winslash = "/", mustWork = FALSE)
    } else {
      NULL
    },
    output_dir = out_norm,
    config = config,
    extras = list(rscript = rscript, r_root = root)
  )
  .runner_state$output_dir <<- ctx$output_dir
  .runner_state$organism_type <<- type
  .runner_state$fasta <<- ctx$fasta_path

  message("[run_analysis] organism_type=", type)
  message("[run_analysis] fasta=", ctx$fasta_path)
  message("[run_analysis] metadata=", if (is.null(ctx$metadata_path)) "<none>" else ctx$metadata_path)
  message("[run_analysis] output=", ctx$output_dir)

  result <- strategy$run(ctx)
  status <- if (is.null(result$status)) "unknown" else result$status
  message("[run_analysis] status=", status)
  if (!is.null(result$error_code)) {
    message("[run_analysis] error_code=", result$error_code)
  }

  if (identical(status, "not_implemented")) {
    # 确保 stub 也带 UNSUPPORTED_ORGANISM
    if (is.null(result$error_code) || !nzchar(as.character(result$error_code)[[1]])) {
      if (exists("write_not_implemented_result", mode = "function")) {
        write_not_implemented_result(
          organism_type = type,
          output_dir = ctx$output_dir,
          error_message = result$error_message %||% "",
          input = input_base,
          statistics = result$statistics %||% list()
        )
      }
    }
    quit(save = "no", status = 2)
  }
  if (!identical(status, "success") && !identical(status, "partial")) {
    quit(save = "no", status = 1)
  }
  quit(save = "no", status = 0)
}

.runner_state <- list(organism_type = "", output_dir = "", fasta = "", exit_hint = 1L)

tryCatch(
  main(),
  error = function(e) {
    msg <- conditionMessage(e)
    message("ERROR: ", msg)
    out_dir <- .runner_state$output_dir
    org <- .runner_state$organism_type
    fasta <- .runner_state$fasta
    input_base <- if (!is.null(fasta) && nzchar(fasta)) basename(fasta) else ""

    if (is_unknown_organism_error(msg)) {
      write_runner_unsupported_organism(
        output_dir = out_dir,
        organism_type = org,
        input = input_base,
        detail = msg
      )
      quit(save = "no", status = 2)
    }

    code <- if (exists("extract_error_code", mode = "function")) {
      extract_error_code(e, default = "")
    } else {
      ""
    }
    if (!nzchar(code) && is_plugin_error(msg, "")) {
      code <- "PLUGIN_LOAD_FAILED"
    }
    write_runner_error_json(
      output_dir = out_dir,
      organism_type = org,
      error_message = msg,
      error_code = code,
      input = input_base
    )
    quit(save = "no", status = 1)
  }
)
