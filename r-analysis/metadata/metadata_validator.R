# =============================================================================
# metadata_validator.R — 统一 metadata 校验
# =============================================================================

REQUIRED_CORE_COLUMNS <- c("sample_id", "organism_type")

SHARED_OPTIONAL_COLUMNS <- c("collection_date", "location", "host")

TYPE_EXTRA_COLUMNS <- list(
  virus = c("segment", "variant"),
  bacteria = c("taxonomy", "environment", "source", "resistance"),
  archaea = c("taxonomy", "habitat", "temperature", "salinity"),
  eukaryote = c("taxonomy", "location", "host", "life_stage")
)
# DEPRECATED FALLBACK (P3/P4)：plugin get_metadata_schema()$extra_columns 优先。
# P4 禁止删除本表。未来 audit 对齐后可清理。见 docs/deprecated_components.md。

# Bacteria 可选分类层级列（不强制；strict 不要求；未知列透传）
BACTERIA_OPTIONAL_TAXONOMY_RANK_COLUMNS <- c(
  "phylum", "class", "order", "family", "genus", "species"
)

#' 解析某类型扩展列：plugin schema 优先，否则 TYPE_EXTRA_COLUMNS（deprecated fallback）
resolve_type_extra_columns <- function(organism_type) {
  organism_type <- tolower(organism_type)
  if (exists("lookup_plugin_metadata_schema", mode = "function")) {
    schema <- lookup_plugin_metadata_schema(organism_type)
    if (is.list(schema) && !is.null(schema$extra_columns)) {
      return(as.character(schema$extra_columns))
    }
  }
  extras <- TYPE_EXTRA_COLUMNS[[organism_type]]
  if (is.null(extras)) {
    stop("未知 organism_type: ", organism_type, call. = FALSE)
  }
  extras
}

#' 返回某类型期望列（核心 + 公共可选 + 类型扩展）
expected_metadata_columns <- function(organism_type) {
  organism_type <- tolower(organism_type)
  extras <- resolve_type_extra_columns(organism_type)
  unique(c(REQUIRED_CORE_COLUMNS, SHARED_OPTIONAL_COLUMNS, extras))
}

#' 校验 metadata data.frame
#'
#' @param meta data.frame
#' @param organism_type 期望类型；若 meta 含 organism_type 列则交叉检查
#' @param strict 若 TRUE，缺少类型扩展列也报错；默认 FALSE（仅警告）
#' @return meta（invisible）；失败 stop
validate_metadata <- function(meta, organism_type, strict = FALSE) {
  if (!is.data.frame(meta)) {
    stop("metadata 必须是 data.frame", call. = FALSE)
  }
  organism_type <- tolower(organism_type)

  missing_core <- setdiff(REQUIRED_CORE_COLUMNS, names(meta))
  if (length(missing_core) > 0) {
    stop("metadata 缺少必需列: ", paste(missing_core, collapse = ", "), call. = FALSE)
  }

  if (nrow(meta) < 1) {
    stop("metadata 至少需要 1 行", call. = FALSE)
  }

  if (any(!nzchar(as.character(meta$sample_id)))) {
    stop("metadata$sample_id 不能为空", call. = FALSE)
  }
  if (anyDuplicated(meta$sample_id)) {
    stop("metadata$sample_id 必须唯一", call. = FALSE)
  }

  types_in_file <- unique(tolower(as.character(meta$organism_type)))
  if (length(types_in_file) != 1) {
    stop("同一任务 metadata 中 organism_type 必须唯一，当前: ",
         paste(types_in_file, collapse = ", "), call. = FALSE)
  }
  if (!identical(types_in_file[[1]], organism_type)) {
    stop("CLI --type=", organism_type,
         " 与 metadata$organism_type=", types_in_file[[1]], " 不一致",
         call. = FALSE)
  }

  extras <- resolve_type_extra_columns(organism_type)
  missing_extra <- setdiff(extras, names(meta))
  if (length(missing_extra) > 0) {
    msg <- paste0("缺少 ", organism_type, " 扩展列: ", paste(missing_extra, collapse = ", "))
    if (strict) stop(msg, call. = FALSE) else warning(msg, call. = FALSE)
  }

  invisible(meta)
}

#' 从 CSV 路径校验
validate_metadata_file <- function(path, organism_type, strict = FALSE) {
  if (!file.exists(path)) {
    stop("metadata 文件不存在: ", path, call. = FALSE)
  }
  meta <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  validate_metadata(meta, organism_type = organism_type, strict = strict)
}
