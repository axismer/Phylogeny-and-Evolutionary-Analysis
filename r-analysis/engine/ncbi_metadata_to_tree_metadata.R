# =============================================================================
# ncbi_metadata_to_tree_metadata.R
# 将 NCBI Virus / GenBank 导出 metadata 转为 ggtree 所需格式
#
# 用法：
#   Rscript ncbi_metadata_to_tree_metadata.R <ncbi_metadata.csv> <tree.nwk|fasta> <out.csv>
#
# 输入（NCBI CSV，列名宽松匹配）：
#   Accession / Strain / Isolate / Geo_Location / Country /
#   Collection_Date / Host / Label_Hint
#
# 输出：
#   label,Country,Year,Host
#   且 metadata$label == tip.label（100% 匹配；按 tip 顺序写出）
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop(
    "用法: Rscript ncbi_metadata_to_tree_metadata.R <ncbi_metadata.csv> <tree.nwk|fasta> <out.csv>",
    call. = FALSE
  )
}

ncbi_file <- args[[1]]
tips_source <- args[[2]]
out_file <- args[[3]]

if (!file.exists(ncbi_file)) stop("NCBI metadata 不存在: ", ncbi_file, call. = FALSE)
if (!file.exists(tips_source)) stop("tip 来源不存在: ", tips_source, call. = FALSE)

# -----------------------------------------------------------------------------
# tip labels：从 Newick 或 FASTA 读取
# -----------------------------------------------------------------------------

read_tips <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("nwk", "newick", "tree")) {
    if (!requireNamespace("ape", quietly = TRUE)) {
      stop("读取 Newick 需要 ape 包", call. = FALSE)
    }
    tr <- ape::read.tree(path)
    return(as.character(tr$tip.label))
  }
  # FASTA headers
  lines <- readLines(path, warn = FALSE)
  hdrs <- lines[grepl("^>", lines)]
  labels <- sub("^>", "", hdrs)
  labels <- sub("\\s.*$", "", labels)
  labels
}

# -----------------------------------------------------------------------------
# 国家 → 大洲（供 ggtree Country 着色）
# -----------------------------------------------------------------------------

COUNTRY_TO_REGION <- c(
  USA = "Americas", `United States` = "Americas", `United States of America` = "Americas",
  Canada = "Americas", Mexico = "Americas", Brazil = "Americas", Chile = "Americas",
  Peru = "Americas", Argentina = "Americas", Colombia = "Americas", Nicaragua = "Americas",
  Japan = "Asia", China = "Asia", `Hong Kong` = "Asia", `South Korea` = "Asia",
  Korea = "Asia", Vietnam = "Asia", Thailand = "Asia", India = "Asia",
  Iran = "Asia", Singapore = "Asia", Taiwan = "Asia",
  `United Kingdom` = "Europe", UK = "Europe", England = "Europe", Scotland = "Europe",
  Denmark = "Europe", Germany = "Europe", France = "Europe", Italy = "Europe",
  Spain = "Europe", Netherlands = "Europe",
  Australia = "Oceania", `New Zealand` = "Oceania",
  `South Africa` = "Africa", Egypt = "Africa", Nigeria = "Africa"
)

geo_to_region <- function(geo) {
  if (is.na(geo) || !nzchar(geo)) return("Americas")
  country <- trimws(strsplit(geo, ":", fixed = TRUE)[[1]][1])
  region <- unname(COUNTRY_TO_REGION[country])
  if (is.na(region) || !nzchar(region)) {
    # 启发式
    if (grepl("USA|United States|Canada|Mexico|Brazil|Chile|Peru|Argentina", country, ignore.case = TRUE)) {
      return("Americas")
    }
    if (grepl("Japan|China|Korea|Vietnam|Thailand|India|Iran|Singapore|Taiwan|Hong Kong", country, ignore.case = TRUE)) {
      return("Asia")
    }
    if (grepl("UK|United Kingdom|Europe|Denmark|Germany|France|Italy|Spain|Scotland", country, ignore.case = TRUE)) {
      return("Europe")
    }
    if (grepl("Australia|New Zealand|Oceania", country, ignore.case = TRUE)) {
      return("Oceania")
    }
    if (grepl("Africa|Egypt|Nigeria", country, ignore.case = TRUE)) {
      return("Africa")
    }
    return("Americas")
  }
  region
}

parse_year <- function(date_str) {
  if (is.na(date_str) || !nzchar(date_str)) return(NA_character_)
  # 优先四位年份
  m <- regexpr("(?:19|20)\\d{2}", date_str, perl = TRUE)
  if (m[1] != -1) return(regmatches(date_str, m))
  NA_character_
}

normalize_host <- function(h) {
  if (is.na(h) || !nzchar(h)) return("Unknown")
  h <- trimws(h)
  if (grepl("homo sapiens|human", h, ignore.case = TRUE)) return("Human")
  if (grepl("swine|pig|sus scrofa", h, ignore.case = TRUE)) return("Swine")
  if (grepl("avian|bird|chicken|duck|poultry", h, ignore.case = TRUE)) return("Avian")
  h
}

# -----------------------------------------------------------------------------
# 读 NCBI CSV，宽松列名
# -----------------------------------------------------------------------------

ncbi <- utils::read.csv(ncbi_file, stringsAsFactors = FALSE, check.names = FALSE)
names_l <- tolower(names(ncbi))

pick_col <- function(..., default = NULL) {
  cands <- tolower(c(...))
  for (c in cands) {
    idx <- match(c, names_l)
    if (!is.na(idx)) return(ncbi[[idx]])
  }
  if (is.null(default)) {
    return(rep(NA_character_, nrow(ncbi)))
  }
  if (length(default) == 1L) rep(default, nrow(ncbi)) else default
}

accession <- as.character(pick_col("accession", "genbank_accession", "nucleotide_accession"))
strain <- as.character(pick_col("strain", "virus_name", "isolate_name"))
isolate <- as.character(pick_col("isolate"))
geo <- as.character(pick_col("geo_location", "geo_loc_name", "country", "geographic_location"))
host_raw <- as.character(pick_col("host"))
coll_date <- as.character(pick_col("collection_date", "collectiondate", "date"))
label_hint <- as.character(pick_col("label_hint", "label"))
travel <- as.character(pick_col("travel_origin_country", "travel_origin"))

# 若有 travel origin，优先用于地理多样性（仍映射为大洲）
geo_for_region <- ifelse(
  !is.na(travel) & nzchar(travel) & travel != "-",
  travel,
  geo
)

# 构造候选 label
make_label <- function(strain_i, accession_i, hint_i) {
  if (!is.na(hint_i) && nzchar(hint_i)) return(hint_i)
  base <- if (!is.na(strain_i) && nzchar(strain_i)) strain_i else accession_i
  base <- gsub("[^A-Za-z0-9]+", "_", base)
  base <- gsub("^_+|_+$", "", base)
  gsub("_+", "_", base)
}

cand_label <- mapply(make_label, strain, accession, label_hint, USE.NAMES = FALSE)

converted <- data.frame(
  label = as.character(cand_label),
  Country = vapply(geo_for_region, geo_to_region, character(1)),
  Year = vapply(coll_date, parse_year, character(1)),
  Host = vapply(host_raw, normalize_host, character(1)),
  Accession = accession,
  stringsAsFactors = FALSE
)

# Year 缺失时尝试从 strain / label 抽
for (i in seq_len(nrow(converted))) {
  if (is.na(converted$Year[i]) || !nzchar(converted$Year[i])) {
    y <- parse_year(paste(strain[i], converted$label[i]))
    converted$Year[i] <- if (!is.na(y)) y else "Unknown"
  }
}

tips <- read_tips(tips_source)
message("tip 数量          : ", length(tips))
message("NCBI 行数         : ", nrow(converted))

# 匹配策略：精确 → 去版本号 accession → 子串
match_one <- function(tip) {
  exact <- which(converted$label == tip)
  if (length(exact) == 1L) return(exact)
  if (length(exact) > 1L) {
    warning("label 重复: ", tip, "；取首条")
    return(exact[[1]])
  }
  # accession 精确
  tip_acc <- sub("\\.\\d+$", "", tip)
  acc_hit <- which(converted$Accession == tip | converted$Accession == tip_acc)
  if (length(acc_hit) >= 1L) return(acc_hit[[1]])
  # tip 含于 strain/label
  soft <- which(grepl(tip, converted$label, fixed = TRUE) |
                  grepl(converted$label, tip, fixed = TRUE))
  soft <- soft[converted$label[soft] != "" & !is.na(converted$label[soft])]
  if (length(soft) == 1L) return(soft)
  NA_integer_
}

idx <- vapply(tips, match_one, integer(1))
missing <- tips[is.na(idx)]
if (length(missing) > 0) {
  stop(
    "无法 100% 匹配 tip.label；缺失 ", length(missing), " 条，示例: ",
    paste(utils::head(missing, 10), collapse = ", "),
    call. = FALSE
  )
}

out <- converted[idx, c("label", "Country", "Year", "Host"), drop = FALSE]
out$label <- tips  # 强制与 tip.label 完全一致
rownames(out) <- NULL

if (!identical(out$label, tips)) {
  stop("写出前 label 仍与 tip.label 不一致", call. = FALSE)
}

dir.create(dirname(normalizePath(out_file, mustWork = FALSE)), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(out, out_file, row.names = FALSE, quote = FALSE)

message("匹配数量          : ", nrow(out), " / ", length(tips))
message("匹配率            : 100%")
message("Country 分布      : ", paste(names(table(out$Country)), table(out$Country), sep = "=", collapse = ", "))
message("Year 分布         : ", paste(names(table(out$Year)), table(out$Year), sep = "=", collapse = ", "))
message("Host 分布         : ", paste(names(table(out$Host)), table(out$Host), sep = "=", collapse = ", "))
message("输出              : ", out_file)
