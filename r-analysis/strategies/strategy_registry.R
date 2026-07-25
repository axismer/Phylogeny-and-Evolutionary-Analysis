# =============================================================================
# strategy_registry.R — Plugin Discovery Registry（Framework v0.3 P3）
#
# 职责：发现 strategies/*/plugin.R → 校验契约 → 注册 → get_strategy(type)
# 禁止：按 organism type 的 switch / 硬编码 builtins 列表
# =============================================================================

.get_framework_dirs <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    here <- dirname(normalizePath(sub("^--file=", "", file_arg[1])))
  } else {
    here <- normalizePath(getwd())
  }
  if (basename(here) == "runners") {
    parent <- normalizePath(file.path(here, ".."), winslash = "/")
    # r-analysis/runners → root; r-analysis/scripts/runners → 再上一级
    if (identical(basename(parent), "scripts")) {
      root <- normalizePath(file.path(parent, ".."), winslash = "/")
    } else {
      root <- parent
    }
  } else if (basename(here) == "strategies") {
    root <- normalizePath(file.path(here, ".."), winslash = "/")
  } else if (basename(dirname(here)) == "strategies") {
    root <- normalizePath(file.path(here, "..", ".."), winslash = "/")
  } else if (basename(here) == "scripts") {
    root <- normalizePath(file.path(here, ".."), winslash = "/")
  } else {
    root <- here
  }
  list(
    root = root,
    core = file.path(root, "core"),
    strategies = file.path(root, "strategies"),
    metadata = file.path(root, "metadata"),
    config = file.path(root, "config")
  )
}

#' 进程内插件注册表（P3 权威来源）
.plugin_registry_env <- new.env(parent = emptyenv())

#' @deprecated 兼容旧名；P3 起与 .plugin_registry_env 同步使用 list_registered
.strategy_registry_env <- .plugin_registry_env

#' source 框架公共模块
source_framework_core <- function(dirs = NULL) {
  if (is.null(dirs)) dirs <- .get_framework_dirs()
  files <- c(
    "strategy_base.R",
    "alignment.R",
    "distance.R",
    "tree_builder.R",
    "visualization.R",
    "result_writer.R",
    "tip_validator.R",
    "strategy_runner.R",
    "plugin_contract.R"
  )
  for (f in files) {
    path <- file.path(dirs$core, f)
    if (!file.exists(path)) {
      # plugin_contract 必选；其余缺失仍报错
      stop("缺少 core 模块: ", path, call. = FALSE)
    }
    source(path, local = FALSE)
  }
  # error_codes 由 result_writer 自举；此处确保 PLUGIN_* 可用
  if (!exists("raise_framework_error", mode = "function")) {
    ec <- file.path(dirs$core, "error_codes.R")
    if (file.exists(ec)) source(ec, local = FALSE)
  }
  meta_validator <- file.path(dirs$metadata, "metadata_validator.R")
  if (file.exists(meta_validator)) {
    source(meta_validator, local = FALSE)
  }
  invisible(dirs)
}

#' 清空插件注册表
clear_plugin_registry <- function() {
  rm(list = ls(envir = .plugin_registry_env, all.names = TRUE), envir = .plugin_registry_env)
  invisible(NULL)
}

#' 已注册类型名
list_registered_strategies <- function() {
  sort(ls(envir = .plugin_registry_env, all.names = FALSE))
}

#' 取已注册 plugin manifest；不存在返回 NULL
get_registered_plugin <- function(organism_type) {
  organism_type <- tolower(as.character(organism_type)[[1]])
  if (!exists(organism_type, envir = .plugin_registry_env, inherits = FALSE)) {
    return(NULL)
  }
  get(organism_type, envir = .plugin_registry_env, inherits = FALSE)
}

#' 注册已校验的 plugin manifest
#'
#' @param manifest build_plugin_manifest() 结果
#' @param overwrite 允许覆盖同 path；跨 path 同 type → PLUGIN_DUPLICATE_TYPE
register_plugin_manifest <- function(manifest, overwrite = FALSE) {
  type <- tolower(as.character(manifest$organism_type)[[1]])
  path <- as.character(manifest$plugin_path)[[1]]
  if (exists(type, envir = .plugin_registry_env, inherits = FALSE)) {
    prev <- get(type, envir = .plugin_registry_env, inherits = FALSE)
    prev_path <- as.character(prev$plugin_path %||% "")[[1]]
    same <- FALSE
    if (nzchar(prev_path) && nzchar(path) && file.exists(prev_path) && file.exists(path)) {
      same <- identical(
        normalizePath(prev_path, winslash = "/", mustWork = FALSE),
        normalizePath(path, winslash = "/", mustWork = FALSE)
      )
    } else if (identical(prev_path, path)) {
      same <- TRUE
    }
    if (same && !overwrite) {
      return(invisible(type))
    }
    if (!overwrite) {
      raise_framework_error(
        "PLUGIN_DUPLICATE_TYPE",
        paste0(
          "duplicate plugin type=", type,
          " existing=", prev_path,
          " new=", path
        )
      )
    }
  }
  assign(type, manifest, envir = .plugin_registry_env)
  invisible(type)
}

#' 加载单个 plugin.R 并注册
load_plugin_file <- function(plugin_path, register = TRUE) {
  plugin_path <- normalizePath(plugin_path, winslash = "/", mustWork = FALSE)
  if (!file.exists(plugin_path)) {
    raise_framework_error(
      "PLUGIN_NOT_FOUND",
      paste0("plugin 不存在: ", plugin_path)
    )
  }

  env <- new.env(parent = globalenv())
  tryCatch(
    source(plugin_path, local = env),
    error = function(e) {
      if (inherits(e, "framework_error")) stop(e)
      raise_framework_error(
        "PLUGIN_LOAD_FAILED",
        paste0("plugin 加载失败: ", plugin_path, " — ", conditionMessage(e))
      )
    }
  )

  validate_plugin_contract(env, plugin_path = plugin_path)

  type <- tolower(as.character(env$get_organism_type())[[1]])
  dir_type <- tolower(basename(dirname(plugin_path)))
  if (nzchar(dir_type) && !identical(dir_type, type)) {
    raise_framework_error(
      "PLUGIN_CONTRACT_INVALID",
      paste0(
        "plugin 目录名与 get_organism_type() 不一致: dir=", dir_type,
        " type=", type, " path=", plugin_path
      )
    )
  }

  manifest <- build_plugin_manifest(env, plugin_path)
  if (isTRUE(register)) {
    register_plugin_manifest(manifest, overwrite = FALSE)
  }
  invisible(manifest)
}

#' 扫描 strategies/*/plugin.R 并注册（无 type switch）
discover_and_register_plugins <- function(dirs = NULL, reset = TRUE) {
  if (is.null(dirs)) dirs <- .get_framework_dirs()
  if (!exists("validate_plugin_contract", mode = "function")) {
    pc <- file.path(dirs$core, "plugin_contract.R")
    if (file.exists(pc)) source(pc, local = FALSE)
  }
  if (isTRUE(reset)) {
    clear_plugin_registry()
  }
  plugin_files <- sort(Sys.glob(file.path(dirs$strategies, "*", "plugin.R")))
  for (pf in plugin_files) {
    load_plugin_file(pf, register = TRUE)
  }
  invisible(plugin_files)
}

#' @deprecated since Framework v0.3 P3
#'
#' Builtins 硬编码列表已移除。本函数保留为空实现 + warning，避免旧脚本硬失败。
#' **P4：禁止删除。** 替代：`discover_and_register_plugins()`。
#' 未来迁移：确认无外部调用后，在专门清理阶段删除（见 docs/deprecated_components.md）。
register_builtin_strategies <- function(dirs) {
  warning(
    "register_builtin_strategies() 已废弃（P3）；请使用 discover_and_register_plugins()。",
    " 详见 docs/deprecated_components.md",
    call. = FALSE
  )
  invisible(NULL)
}

#' @deprecated 兼容旧名 → discover_and_register_plugins
load_strategy_plugins <- function(dirs) {
  discover_and_register_plugins(dirs, reset = FALSE)
}

#' @deprecated 低层登记；P3 生产路径走 plugin.R
register_strategy <- function(organism_type,
                              factory = NULL,
                              strategy_file = NULL,
                              overwrite = FALSE) {
  organism_type <- tolower(as.character(organism_type)[[1]])
  if (!nzchar(organism_type)) {
    stop("register_strategy: organism_type 不能为空", call. = FALSE)
  }
  if (!overwrite && exists(organism_type, envir = .plugin_registry_env, inherits = FALSE)) {
    raise_framework_error(
      "PLUGIN_DUPLICATE_TYPE",
      paste0("duplicate plugin type=", organism_type)
    )
  }
  if (is.null(factory) && is.null(strategy_file)) {
    stop("register_strategy: 需要 factory 和/或 strategy_file", call. = FALSE)
  }
  manifest <- list(
    organism_type = organism_type,
    status = "production",
    plugin_path = strategy_file %||% "",
    get_strategy = if (is.function(factory)) {
      factory
    } else {
      function() {
        stop("register_strategy legacy entry missing factory", call. = FALSE)
      }
    },
    get_metadata_schema = function() list(organism_type = organism_type, extra_columns = character()),
    get_default_config = function() list(),
    get_organism_type = function() organism_type,
    get_status = function() "production"
  )
  assign(organism_type, manifest, envir = .plugin_registry_env)
  invisible(organism_type)
}

#' 按 organism_type 加载并返回 Strategy 实例（无 switch）
get_strategy <- function(organism_type) {
  organism_type <- tolower(as.character(organism_type)[[1]])
  dirs <- source_framework_core()
  discover_and_register_plugins(dirs, reset = TRUE)

  entry <- get_registered_plugin(organism_type)
  if (is.null(entry)) {
    stop(
      "未知 --type: ", organism_type,
      "；已注册: ", paste(list_registered_strategies(), collapse = ", "),
      call. = FALSE
    )
  }

  strategy <- tryCatch(
    entry$get_strategy(),
    error = function(e) {
      if (inherits(e, "framework_error")) stop(e)
      raise_framework_error(
        "PLUGIN_LOAD_FAILED",
        paste0(
          "plugin get_strategy() 失败 type=", organism_type,
          " — ", conditionMessage(e)
        )
      )
    }
  )
  assert_phylo_strategy(strategy)
  strategy
}

`%||%` <- function(a, b) {
  if (is.null(a) || (length(a) == 1 && is.na(a))) b else a
}
