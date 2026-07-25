# =============================================================================
# prepare_h3n2_ha_benchmark.R
# 从 NCBI 分层抽样真实 Influenza A H3N2 HA（Human, complete, 2005–2024）
#
# 用法：
#   Rscript prepare_h3n2_ha_benchmark.R [output_dir] [target_n]
#
# 输出：
#   h3n2_ha_unaligned.fasta  — 未比对完整序列
#   ncbi_metadata.csv        — NCBI 风格元数据
#   sampling_report.txt      — 抽样统计
# =============================================================================

args <- commandArgs(trailingOnly = TRUE)
out_dir <- if (length(args) >= 1) args[[1]] else "../../data/benchmarks/h3n2_ha"
target_n <- if (length(args) >= 2) as.integer(args[[2]]) else 220L
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_dir <- normalizePath(out_dir, winslash = "/", mustWork = TRUE)

# -----------------------------------------------------------------------------
# 分层设计：4 大区 × 多国家 × 年份箱，避免同年同地扎堆
# -----------------------------------------------------------------------------

STRATA <- list(
  Americas = list(
    countries = c("USA", "Canada", "Mexico", "Brazil", "Chile", "Peru", "Argentina"),
    years = 2005:2024
  ),
  Asia = list(
    countries = c("Japan", "China", "South Korea", "Korea", "Thailand", "Singapore",
                  "India", "Hong Kong", "Taiwan", "Vietnam"),
    years = 2005:2024
  ),
  Europe = list(
    countries = c("United Kingdom", "England", "Germany", "France", "Italy",
                  "Spain", "Denmark", "Netherlands", "Sweden", "Norway"),
    years = 2005:2024
  ),
  Oceania = list(
    countries = c("Australia", "New Zealand"),
    years = 2005:2024
  )
)

YEAR_BINS <- list(
  `2005-2008` = 2005:2008,
  `2009-2012` = 2009:2012,
  `2013-2016` = 2013:2016,
  `2017-2020` = 2017:2020,
  `2021-2024` = 2021:2024
)

# 每层目标：约 target_n / (4*5)；略提高以减少事后补样偏斜
per_stratum <- max(10L, as.integer(ceiling(target_n / (4 * length(YEAR_BINS)))))

sleep_ncbi <- function(sec = 0.35) Sys.sleep(sec)

ncbi_get <- function(url, retries = 4L) {
  last_err <- NULL
  for (i in seq_len(retries)) {
    txt <- tryCatch(
      {
        con <- url(url, open = "rb")
        on.exit(close(con), add = TRUE)
        rawToChar(readBin(con, what = "raw", n = 5e7))
      },
      error = function(e) {
        last_err <<- e
        NULL
      }
    )
    if (!is.null(txt) && nzchar(txt)) return(txt)
    sleep_ncbi(0.8 * i)
  }
  stop("NCBI 请求失败: ", url, " ; ", conditionMessage(last_err), call. = FALSE)
}

esearch_ids <- function(term, retmax = 80L) {
  q <- utils::URLencode(term, reserved = TRUE)
  api <- paste0(
    "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?",
    "db=nuccore&retmode=json&retmax=", retmax, "&term=", q
  )
  sleep_ncbi()
  js <- ncbi_get(api)
  # 轻量解析 idlist（避免依赖 jsonlite）
  if (!grepl('"idlist"', js, fixed = TRUE)) return(character(0))
  block <- sub('.*"idlist"\\s*:\\s*\\[([^\\]]*)\\].*', "\\1", js, perl = TRUE)
  ids <- unlist(regmatches(block, gregexpr("\\d+", block, perl = TRUE)))
  unique(as.character(ids))
}

efetch_gb <- function(ids) {
  if (length(ids) < 1) return("")
  # 分批，避免 URL 过长
  chunks <- split(ids, ceiling(seq_along(ids) / 40))
  parts <- character(0)
  for (ch in chunks) {
    api <- paste0(
      "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?",
      "db=nuccore&rettype=gb&retmode=text&id=", paste(ch, collapse = ",")
    )
    sleep_ncbi(0.4)
    parts <- c(parts, ncbi_get(api))
  }
  paste(parts, collapse = "\n")
}

extract_group <- function(text, pattern) {
  m <- regexec(pattern, text, perl = TRUE)
  if (m[[1]][1] == -1) return(NA_character_)
  regmatches(text, m)[[1]][2]
}

parse_origin_seq <- function(text) {
  origin <- sub("(?s).*?\\nORIGIN\\s*\\n", "", text, perl = TRUE)
  origin <- sub("(?s)//\\s*$", "", origin, perl = TRUE)
  seq <- gsub("[0-9\\s]+", "", origin, perl = TRUE)
  toupper(seq)
}

sanitize_label <- function(strain, accession) {
  base <- if (!is.na(strain) && nzchar(strain)) strain else accession
  base <- gsub("[^A-Za-z0-9]+", "_", base)
  base <- gsub("^_+|_+$", "", base)
  gsub("_+", "_", base)
}

parse_year <- function(date_str) {
  if (is.na(date_str) || !nzchar(date_str)) return(NA_integer_)
  m <- regexpr("(?:19|20)\\d{2}", date_str, perl = TRUE)
  if (m[1] == -1) return(NA_integer_)
  as.integer(regmatches(date_str, m))
}

is_human_host <- function(h) {
  if (is.na(h) || !nzchar(h)) return(FALSE)
  grepl("homo sapiens|human", h, ignore.case = TRUE) &&
    !grepl("swine|avian|duck|chicken|pig", h, ignore.case = TRUE)
}

geo_country <- function(geo) {
  if (is.na(geo) || !nzchar(geo)) return(NA_character_)
  trimws(strsplit(geo, ":", fixed = TRUE)[[1]][1])
}

country_to_region <- function(country) {
  if (is.na(country) || !nzchar(country)) return(NA_character_)
  map <- c(
    USA = "Americas", `United States` = "Americas", Canada = "Americas",
    Mexico = "Americas", Brazil = "Americas", Chile = "Americas",
    Peru = "Americas", Argentina = "Americas", Colombia = "Americas",
    Japan = "Asia", China = "Asia", `Hong Kong` = "Asia",
    `South Korea` = "Asia", Korea = "Asia", Vietnam = "Asia",
    Thailand = "Asia", India = "Asia", Singapore = "Asia", Taiwan = "Asia",
    `United Kingdom` = "Europe", England = "Europe", Scotland = "Europe",
    UK = "Europe", Denmark = "Europe", Germany = "Europe", France = "Europe",
    Italy = "Europe", Spain = "Europe", Netherlands = "Europe",
    Sweden = "Europe", Norway = "Europe",
    Australia = "Oceania", `New Zealand` = "Oceania"
  )
  r <- unname(map[country])
  if (!is.na(r)) return(r)
  if (grepl("USA|United States|Canada|Mexico|Brazil|Chile|Peru|Argentina", country, ignore.case = TRUE)) {
    return("Americas")
  }
  if (grepl("Japan|China|Korea|Vietnam|Thailand|India|Singapore|Taiwan|Hong Kong", country, ignore.case = TRUE)) {
    return("Asia")
  }
  if (grepl("UK|United Kingdom|England|Denmark|Germany|France|Italy|Spain|Netherlands|Sweden|Norway", country, ignore.case = TRUE)) {
    return("Europe")
  }
  if (grepl("Australia|New Zealand", country, ignore.case = TRUE)) {
    return("Oceania")
  }
  NA_character_
}

parse_gb_records <- function(gb_text) {
  gb_text <- gsub("\r", "", gb_text, fixed = TRUE)
  if (!grepl("^LOCUS ", gb_text)) return(list())
  parts <- strsplit(gb_text, "\nLOCUS ", fixed = TRUE)[[1]]
  if (length(parts) > 1) {
    parts <- c(parts[[1]], paste0("LOCUS ", parts[-1]))
  }
  parts <- parts[nzchar(trimws(parts))]
  rows <- list()
  for (rec in parts) {
    accession <- extract_group(rec, "(?m)^ACCESSION\\s+(\\S+)")
    version <- extract_group(rec, "(?m)^VERSION\\s+(\\S+)")
    strain <- extract_group(rec, '/strain="([^"]+)"')
    isolate <- extract_group(rec, '/isolate="([^"]+)"')
    serotype <- extract_group(rec, '/serotype="([^"]+)"')
    geo <- extract_group(rec, '/geo_loc_name="([^"]+)"')
    host_val <- extract_group(rec, '/host="([^"]+)"')
    coll_date <- extract_group(rec, '/collection_date="([^"]+)"')
    isolation_source <- extract_group(rec, '/isolation_source="([^"]+)"')
    definition <- extract_group(rec, "(?m)^DEFINITION\\s+(.+?)(?=\\nACCESSION)")
    definition <- if (is.na(definition)) NA_character_ else gsub("\\s+", " ", definition)
    seq <- parse_origin_seq(rec)
    if (is.na(seq) || !nzchar(seq)) next
    year <- parse_year(coll_date)
    if (is.na(year) && !is.na(strain)) year <- parse_year(strain)
    country <- geo_country(geo)
    region <- country_to_region(country)
    label <- sanitize_label(strain, accession)
    rows[[length(rows) + 1L]] <- data.frame(
      Accession = accession,
      Version = version,
      Strain = strain,
      Isolate = isolate,
      Serotype = serotype,
      Geo_Location = geo,
      Country_Raw = country,
      Region = region,
      Host = host_val,
      Collection_Date = coll_date,
      Isolation_Source = isolation_source,
      Year = year,
      Length = nchar(seq),
      Definition = definition,
      Label_Hint = label,
      Sequence = seq,
      stringsAsFactors = FALSE
    )
  }
  rows
}

# -----------------------------------------------------------------------------
# 分层检索 + 下载
# -----------------------------------------------------------------------------

message("======== H3N2 HA benchmark prepare ========")
message("output_dir = ", out_dir)
message("target_n   = ", target_n)
message("per_stratum≈ ", per_stratum)

set.seed(42)
all_rows <- list()
seen_acc <- character(0)
report_lines <- c(
  paste0("timestamp=", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  paste0("target_n=", target_n),
  paste0("per_stratum=", per_stratum)
)

for (region in names(STRATA)) {
  countries <- STRATA[[region]]$countries
  for (bin_name in names(YEAR_BINS)) {
    years <- YEAR_BINS[[bin_name]]
    y1 <- min(years)
    y2 <- max(years)
    # 轮询国家，凑够本层额度
    need <- per_stratum
    stratum_ids <- character(0)
    for (country in sample(countries)) {
      if (length(stratum_ids) >= need * 3L) break
      # PDAT 作粗筛；真正年份用 collection_date 再过滤
      term <- paste0(
        'Influenza A virus[Organism] AND H3N2 AND "segment 4"[Title] AND ',
        "Homo sapiens[Host] AND 1680:1770[SLEN] AND ",
        country, "[All Fields] AND ",
        y1, ":", y2, "[PDAT]"
      )
      ids <- tryCatch(esearch_ids(term, retmax = 60L), error = function(e) {
        message("[警告] esearch 失败 ", region, "/", bin_name, "/", country, ": ",
                conditionMessage(e))
        character(0)
      })
      ids <- setdiff(ids, seen_acc)
      if (length(ids) > 0) {
        stratum_ids <- unique(c(stratum_ids, ids))
        message(region, " | ", bin_name, " | ", country, " -> +", length(ids),
                " (pool=", length(stratum_ids), ")")
      }
    }
    if (length(stratum_ids) < 1) {
      report_lines <- c(report_lines, paste0(region, "/", bin_name, "=0"))
      next
    }
    # 取比需要略多的 ID 再过滤
    take_n <- min(length(stratum_ids), need * 4L)
    pick <- sample(stratum_ids, take_n)
    gb <- tryCatch(efetch_gb(pick), error = function(e) {
      message("[警告] efetch 失败: ", conditionMessage(e))
      ""
    })
    parsed <- parse_gb_records(gb)
    if (length(parsed) < 1) {
      report_lines <- c(report_lines, paste0(region, "/", bin_name, "=0_parse"))
      next
    }
    df <- do.call(rbind, parsed)
    # 硬过滤
    keep <- which(
      !is.na(df$Year) & df$Year >= 2005L & df$Year <= 2024L &
        df$Year %in% years &
        vapply(df$Host, is_human_host, logical(1)) &
        !is.na(df$Region) & df$Region == region &
        df$Length >= 1680L & df$Length <= 1770L &
        (is.na(df$Serotype) | grepl("H3N2", df$Serotype, ignore.case = TRUE) |
           grepl("H3N2", df$Definition, ignore.case = TRUE) |
           grepl("H3N2", df$Strain, ignore.case = TRUE)) &
        !df$Accession %in% seen_acc
    )
    df <- df[keep, , drop = FALSE]
    if (nrow(df) < 1) {
      report_lines <- c(report_lines, paste0(region, "/", bin_name, "=0_filter"))
      next
    }
    # 本层内再按国家分散
    if (nrow(df) > need) {
      # 轮询国家抽样
      by_c <- split(seq_len(nrow(df)), df$Country_Raw)
      sel <- integer(0)
      while (length(sel) < need && length(by_c) > 0) {
        for (nm in names(by_c)) {
          if (length(sel) >= need) break
          if (length(by_c[[nm]]) < 1) next
          sel <- c(sel, by_c[[nm]][1])
          by_c[[nm]] <- by_c[[nm]][-1]
        }
        by_c <- by_c[vapply(by_c, length, integer(1)) > 0]
      }
      df <- df[sel, , drop = FALSE]
    }
    seen_acc <- c(seen_acc, df$Accession)
    all_rows[[length(all_rows) + 1L]] <- df
    message("  kept ", nrow(df), " for ", region, "/", bin_name)
    report_lines <- c(report_lines, paste0(region, "/", bin_name, "=", nrow(df)))
  }
}

if (length(all_rows) < 1) {
  stop("未下载到任何合格序列", call. = FALSE)
}

meta <- do.call(rbind, all_rows)
rownames(meta) <- NULL

# YearBin 辅助
assign_year_bin <- function(years) {
  cut(
    years,
    breaks = c(2004, 2008, 2012, 2016, 2020, 2024),
    labels = names(YEAR_BINS),
    include.lowest = TRUE
  )
}

# 按「大区 × 年份箱」配额补样，避免美洲/近年扎堆
if (nrow(meta) < target_n) {
  message("[补样] 当前 ", nrow(meta), " < ", target_n, "，按层配额补齐 ...")
  region_quota <- as.integer(ceiling(target_n / length(STRATA)))
  for (region in names(STRATA)) {
    n_reg <- sum(meta$Region == region)
    if (n_reg >= region_quota) next
    need_reg <- region_quota - n_reg
    message("  大区 ", region, " 需补 ", need_reg)
    for (bin_name in names(YEAR_BINS)) {
      if (need_reg <= 0 || nrow(meta) >= target_n) break
      years <- YEAR_BINS[[bin_name]]
      n_bin <- sum(meta$Region == region & meta$Year %in% years)
      bin_cap <- max(2L, as.integer(ceiling(region_quota / length(YEAR_BINS))))
      if (n_bin >= bin_cap) next
      need_bin <- min(bin_cap - n_bin, need_reg, target_n - nrow(meta))
      if (need_bin <= 0) next
      y1 <- min(years)
      y2 <- max(years)
      pool_ids <- character(0)
      for (country in sample(STRATA[[region]]$countries)) {
        if (length(pool_ids) >= need_bin * 5L) break
        term <- paste0(
          'Influenza A virus[Organism] AND H3N2 AND "segment 4"[Title] AND ',
          "Homo sapiens[Host] AND 1680:1770[SLEN] AND ",
          country, "[All Fields] AND ",
          y1, ":", y2, "[PDAT]"
        )
        ids <- tryCatch(esearch_ids(term, retmax = 80L), error = function(e) character(0))
        pool_ids <- unique(c(pool_ids, setdiff(ids, seen_acc)))
      }
      if (length(pool_ids) < 1) next
      pick <- sample(pool_ids, min(length(pool_ids), need_bin * 4L))
      gb <- tryCatch(efetch_gb(pick), error = function(e) "")
      parsed <- parse_gb_records(gb)
      if (length(parsed) < 1) next
      df <- do.call(rbind, parsed)
      keep <- which(
        !is.na(df$Year) & df$Year >= 2005L & df$Year <= 2024L &
          df$Year %in% years &
          vapply(df$Host, is_human_host, logical(1)) &
          !is.na(df$Region) & df$Region == region &
          df$Length >= 1680L & df$Length <= 1770L &
          !df$Accession %in% seen_acc
      )
      df <- df[keep, , drop = FALSE]
      if (nrow(df) < 1) next
      # 国家轮询，避免单国垄断
      by_c <- split(seq_len(nrow(df)), df$Country_Raw)
      sel <- integer(0)
      while (length(sel) < need_bin && length(by_c) > 0) {
        for (nm in names(by_c)) {
          if (length(sel) >= need_bin) break
          if (length(by_c[[nm]]) < 1) next
          sel <- c(sel, by_c[[nm]][1])
          by_c[[nm]] <- by_c[[nm]][-1]
        }
        by_c <- by_c[vapply(by_c, length, integer(1)) > 0]
      }
      df <- df[sel, , drop = FALSE]
      seen_acc <- c(seen_acc, df$Accession)
      meta <- rbind(meta, df)
      need_reg <- need_reg - nrow(df)
      message("    补样 +", nrow(df), " ", region, "/", bin_name, " total=", nrow(meta))
    }
  }
}

# 最终再平衡：大区 × 年份箱配额，上限 300，目标 target_n
meta$YearBin <- assign_year_bin(meta$Year)
desired <- min(300L, max(150L, target_n))
n_strata <- max(1L, length(unique(as.character(paste(meta$Region, meta$YearBin)))))
quota <- as.integer(ceiling(desired / n_strata))
keep_idx <- integer(0)
for (grp in split(seq_len(nrow(meta)), paste(meta$Region, meta$YearBin))) {
  # 层内再按国家分散
  if (length(grp) <= quota) {
    keep_idx <- c(keep_idx, grp)
  } else {
    sub <- meta[grp, , drop = FALSE]
    by_c <- split(grp, sub$Country_Raw)
    sel <- integer(0)
    while (length(sel) < quota && length(by_c) > 0) {
      for (nm in names(by_c)) {
        if (length(sel) >= quota) break
        if (length(by_c[[nm]]) < 1) next
        sel <- c(sel, by_c[[nm]][1])
        by_c[[nm]] <- by_c[[nm]][-1]
      }
      by_c <- by_c[vapply(by_c, length, integer(1)) > 0]
    }
    keep_idx <- c(keep_idx, sel)
  }
}
if (length(keep_idx) < 150L) {
  keep_idx <- seq_len(nrow(meta))
}
meta <- meta[keep_idx, , drop = FALSE]
meta$YearBin <- NULL
rownames(meta) <- NULL

# 唯一 label
meta$Label_Hint <- vapply(
  seq_len(nrow(meta)),
  function(i) sanitize_label(meta$Strain[i], meta$Accession[i]),
  character(1)
)
dups <- duplicated(meta$Label_Hint) | duplicated(meta$Label_Hint, fromLast = TRUE)
meta$Label_Hint[dups] <- paste0(meta$Label_Hint[dups], "_", meta$Accession[dups])

# 写 FASTA + metadata（去掉 Sequence 列到 CSV）
fasta_path <- file.path(out_dir, "h3n2_ha_unaligned.fasta")
fasta_lines <- character(0)
for (i in seq_len(nrow(meta))) {
  fasta_lines <- c(fasta_lines, paste0(">", meta$Label_Hint[i]), meta$Sequence[i])
}
writeLines(fasta_lines, fasta_path)

meta_out <- meta[, setdiff(names(meta), "Sequence"), drop = FALSE]
csv_path <- file.path(out_dir, "ncbi_metadata.csv")
utils::write.csv(meta_out, csv_path, row.names = FALSE, quote = TRUE)

# 报告
yr_tab <- table(meta$Year)
ct_tab <- table(meta$Country_Raw)
rg_tab <- table(meta$Region)
report_lines <- c(
  report_lines,
  paste0("final_n=", nrow(meta)),
  paste0("length_range=", min(meta$Length), "-", max(meta$Length)),
  paste0("year_span=", min(meta$Year), "-", max(meta$Year)),
  paste0("n_years=", length(unique(meta$Year))),
  paste0("n_countries=", length(unique(meta$Country_Raw))),
  paste0("regions=", paste(names(rg_tab), rg_tab, sep = "=", collapse = ", ")),
  paste0("years=", paste(names(yr_tab), yr_tab, sep = "=", collapse = ", ")),
  paste0("countries=", paste(names(ct_tab), ct_tab, sep = "=", collapse = ", "))
)
report_path <- file.path(out_dir, "sampling_report.txt")
writeLines(report_lines, report_path)

message("======== DONE ========")
message("sequences : ", nrow(meta))
message("years     : ", min(meta$Year), "-", max(meta$Year),
        " (n=", length(unique(meta$Year)), ")")
message("countries : ", length(unique(meta$Country_Raw)))
message("regions   : ", paste(names(rg_tab), rg_tab, sep = "=", collapse = ", "))
message("FASTA     : ", fasta_path)
message("metadata  : ", csv_path)
message("report    : ", report_path)

if (nrow(meta) < 150L) {
  stop("合格序列不足 150（当前 ", nrow(meta), "），请重试或放宽条件", call. = FALSE)
}
if (length(unique(meta$Year)) < 10L) {
  stop("年份跨度不足 10 年（当前 ", length(unique(meta$Year)), "）", call. = FALSE)
}
if (length(unique(meta$Country_Raw)) < 5L) {
  stop("国家不足 5 个（当前 ", length(unique(meta$Country_Raw)), "）", call. = FALSE)
}
invisible(NULL)
