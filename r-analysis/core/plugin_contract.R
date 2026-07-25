# =============================================================================
# plugin_contract.R — Organism Plugin 统一契约（Framework v0.3 P3）
#
# 每个 strategies/<type>/plugin.R 必须提供：
#   get_organism_type() / get_strategy() / get_metadata_schema() /
#   get_default_config() / get_status()
# =============================================================================

PLUGIN_REQUIRED_FUNCTIONS <- c(
  "get_organism_type",
  "get_strategy",
  "get_metadata_schema",
  "get_default_config",
  "get_status"
)

PLUGIN_STATUS_VALUES <- c("production", "stub")

#' 校验 plugin 环境是否满足契约
#'
#' @param plugin_env 含契约函数的 environment 或具名 list
#' @param plugin_path 可选路径（用于错误消息）
#' @return invisible(TRUE)；失败 raise PLUGIN_CONTRACT_INVALID
validate_plugin_contract <- function(plugin_env, plugin_path = "") {
  loc <- if (nzchar(as.character(plugin_path)[[1]])) {
    paste0(" (", plugin_path, ")")
  } else {
    ""
  }

  get_fn <- function(name) {
    if (is.environment(plugin_env)) {
      if (!exists(name, envir = plugin_env, inherits = FALSE)) return(NULL)
      plugin_env[[name]]
    } else if (is.list(plugin_env)) {
      plugin_env[[name]]
    } else {
      NULL
    }
  }

  missing <- character()
  for (nm in PLUGIN_REQUIRED_FUNCTIONS) {
    fn <- get_fn(nm)
    if (!is.function(fn)) missing <- c(missing, nm)
  }
  if (length(missing) > 0) {
    raise_framework_error(
      "PLUGIN_CONTRACT_INVALID",
      paste0(
        "plugin contract 缺少函数: ", paste(missing, collapse = ", "),
        loc
      )
    )
  }

  type <- tryCatch(
    get_fn("get_organism_type")(),
    error = function(e) {
      raise_framework_error(
        "PLUGIN_CONTRACT_INVALID",
        paste0("get_organism_type() 失败", loc, ": ", conditionMessage(e))
      )
    }
  )
  if (!is.character(type) || length(type) != 1L || !nzchar(trimws(type))) {
    raise_framework_error(
      "PLUGIN_CONTRACT_INVALID",
      paste0("get_organism_type() 必须返回非空字符串", loc)
    )
  }

  status <- tryCatch(
    get_fn("get_status")(),
    error = function(e) {
      raise_framework_error(
        "PLUGIN_CONTRACT_INVALID",
        paste0("get_status() 失败", loc, ": ", conditionMessage(e))
      )
    }
  )
  status <- as.character(status)[[1]]
  if (!status %in% PLUGIN_STATUS_VALUES) {
    raise_framework_error(
      "PLUGIN_CONTRACT_INVALID",
      paste0(
        "get_status() 必须是 production|stub，实际: ", status, loc
      )
    )
  }

  schema <- tryCatch(
    get_fn("get_metadata_schema")(),
    error = function(e) {
      raise_framework_error(
        "PLUGIN_CONTRACT_INVALID",
        paste0("get_metadata_schema() 失败", loc, ": ", conditionMessage(e))
      )
    }
  )
  if (!is.list(schema)) {
    raise_framework_error(
      "PLUGIN_CONTRACT_INVALID",
      paste0("get_metadata_schema() 必须返回 list", loc)
    )
  }

  cfg <- tryCatch(
    get_fn("get_default_config")(),
    error = function(e) {
      raise_framework_error(
        "PLUGIN_CONTRACT_INVALID",
        paste0("get_default_config() 失败", loc, ": ", conditionMessage(e))
      )
    }
  )
  if (!is.list(cfg)) {
    raise_framework_error(
      "PLUGIN_CONTRACT_INVALID",
      paste0("get_default_config() 必须返回 list", loc)
    )
  }

  invisible(TRUE)
}

#' 从已加载 plugin 环境构建 registry 条目
build_plugin_manifest <- function(plugin_env, plugin_path) {
  list(
    organism_type = as.character(plugin_env$get_organism_type())[[1]],
    status = as.character(plugin_env$get_status())[[1]],
    plugin_path = plugin_path,
    get_strategy = plugin_env$get_strategy,
    get_metadata_schema = plugin_env$get_metadata_schema,
    get_default_config = plugin_env$get_default_config,
    get_organism_type = plugin_env$get_organism_type,
    get_status = plugin_env$get_status,
    env = plugin_env
  )
}

#' 查询已注册 plugin 的 metadata schema（无则 NULL）
lookup_plugin_metadata_schema <- function(organism_type) {
  organism_type <- tolower(as.character(organism_type)[[1]])
  if (!exists("get_registered_plugin", mode = "function")) return(NULL)
  entry <- get_registered_plugin(organism_type)
  if (is.null(entry) || !is.function(entry$get_metadata_schema)) return(NULL)
  tryCatch(entry$get_metadata_schema(), error = function(...) NULL)
}

#' 查询已注册 plugin 的 default config（无则 NULL）
lookup_plugin_default_config <- function(organism_type) {
  organism_type <- tolower(as.character(organism_type)[[1]])
  if (!exists("get_registered_plugin", mode = "function")) return(NULL)
  entry <- get_registered_plugin(organism_type)
  if (is.null(entry) || !is.function(entry$get_default_config)) return(NULL)
  tryCatch(entry$get_default_config(), error = function(...) NULL)
}
