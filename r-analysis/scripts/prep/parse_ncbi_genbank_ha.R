# =============================================================================
# parse_ncbi_genbank_ha.R
# 从 NCBI GenBank flat file 提取 H3N2 HA FASTA + NCBI 风格 metadata CSV
#
# 用法：
#   Rscript parse_ncbi_genbank_ha.R <input.gb> <output_dir>
#
# 输出：
#   h3n2_ha.fasta
#   ncbi_metadata.csv   （NCBI Virus 风格列，供转换脚本使用）
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("用法: Rscript parse_ncbi_genbank_ha.R <input.gb> <output_dir>", call. = FALSE)
}

gb_file <- args[[1]]
out_dir <- args[[2]]
if (!file.exists(gb_file)) stop("GenBank 文件不存在: ", gb_file, call. = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

raw_lines <- readLines(gb_file, warn = FALSE, encoding = "UTF-8")
if (length(raw_lines) < 1) {
  raw_lines <- readLines(gb_file, warn = FALSE)
}
gb_text <- paste(raw_lines, collapse = "\n")
gb_text <- gsub("\r", "", gb_text, fixed = TRUE)
# 按 LOCUS 切分记录（兼容 CRLF / 无前瞻）
if (grepl("^LOCUS ", gb_text)) {
  parts <- strsplit(gb_text, "\nLOCUS ", fixed = TRUE)[[1]]
  if (length(parts) > 1) {
    parts <- c(parts[[1]], paste0("LOCUS ", parts[-1]))
  }
} else {
  parts <- character(0)
}
parts <- parts[nzchar(trimws(parts))]
if (length(parts) < 1) stop("未找到 LOCUS 记录", call. = FALSE)
message("解析到 LOCUS 记录: ", length(parts))

extract_field <- function(text, pattern) {
  m <- regexpr(pattern, text, perl = TRUE)
  if (m[1] == -1) return(NA_character_)
  regmatches(text, m)
}

extract_group <- function(text, pattern) {
  m <- regexec(pattern, text, perl = TRUE)
  if (m[[1]][1] == -1) return(NA_character_)
  regmatches(text, m)[[1]][2]
}

sanitize_label <- function(strain, accession) {
  base <- if (!is.na(strain) && nzchar(strain)) strain else accession
  base <- gsub("[^A-Za-z0-9]+", "_", base)
  base <- gsub("^_+|_+$", "", base)
  base <- gsub("_+", "_", base)
  base
}

parse_origin_seq <- function(text) {
  origin <- sub("(?s).*?\\nORIGIN\\s*\\n", "", text, perl = TRUE)
  origin <- sub("(?s)//\\s*$", "", origin, perl = TRUE)
  # 去掉行号与空白
  seq <- gsub("[0-9\\s]+", "", origin, perl = TRUE)
  toupper(seq)
}

rows <- list()
fasta_lines <- character(0)

for (i in seq_along(parts)) {
  rec <- parts[[i]]
  accession <- extract_group(rec, "(?m)^ACCESSION\\s+(\\S+)")
  version <- extract_group(rec, "(?m)^VERSION\\s+(\\S+)")
  strain <- extract_group(rec, '/strain="([^"]+)"')
  isolate <- extract_group(rec, '/isolate="([^"]+)"')
  serotype <- extract_group(rec, '/serotype="([^"]+)"')
  geo <- extract_group(rec, '/geo_loc_name="([^"]+)"')
  host_val <- extract_group(rec, '/host="([^"]+)"')
  coll_date <- extract_group(rec, '/collection_date="([^"]+)"')
  isolation_source <- extract_group(rec, '/isolation_source="([^"]+)"')
  travel_origin <- extract_group(rec, "travel_origin_country\\s*::\\s*(\\S+)")
  definition <- extract_group(rec, "(?m)^DEFINITION\\s+(.+?)(?=\\nACCESSION)")
  definition <- gsub("\\s+", " ", definition)
  seq <- parse_origin_seq(rec)
  if (is.na(seq) || !nzchar(seq)) {
    warning("跳过无序列记录: ", accession)
    next
  }

  label <- sanitize_label(strain, accession)
  rows[[length(rows) + 1L]] <- data.frame(
    Accession = accession,
    Version = version,
    Strain = strain,
    Isolate = isolate,
    Serotype = serotype,
    Geo_Location = geo,
    Host = host_val,
    Collection_Date = coll_date,
    Isolation_Source = isolation_source,
    Travel_Origin_Country = travel_origin,
    Length = nchar(seq),
    Definition = definition,
    Label_Hint = label,
    stringsAsFactors = FALSE
  )
  fasta_lines <- c(fasta_lines, paste0(">", label), seq)
}

meta <- do.call(rbind, rows)
# 保证 label 唯一
if (anyDuplicated(meta$Label_Hint) > 0) {
  dups <- duplicated(meta$Label_Hint) | duplicated(meta$Label_Hint, fromLast = TRUE)
  meta$Label_Hint[dups] <- paste0(meta$Label_Hint[dups], "_", meta$Accession[dups])
  # 重建 FASTA 头
  fasta_lines <- character(0)
  for (j in seq_len(nrow(meta))) {
    # 重新从 parts 取序列 —— 简化：用 Accession 匹配
    stop("检测到重复 label，请检查 strain 命名", call. = FALSE)
  }
}

fasta_file <- file.path(out_dir, "h3n2_ha.fasta")
ncbi_csv <- file.path(out_dir, "ncbi_metadata.csv")
writeLines(fasta_lines, fasta_file)
utils::write.csv(meta, ncbi_csv, row.names = FALSE, quote = TRUE)

message("序列数          : ", nrow(meta))
message("长度范围        : ", min(meta$Length), " - ", max(meta$Length))
message("FASTA           : ", fasta_file)
message("NCBI metadata   : ", ncbi_csv)
message("字段            : ", paste(names(meta), collapse = ", "))
