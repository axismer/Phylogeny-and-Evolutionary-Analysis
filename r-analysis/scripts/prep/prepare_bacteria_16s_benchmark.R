# =============================================================================
# prepare_bacteria_16s_benchmark.R
# 将 NCBI 下载的真实 16S FASTA 规范化为基准输入 + metadata.csv
# =============================================================================

raw <- "d:/Projects/phylo-platform/r-analysis/data/benchmarks/bacteria_16s/_ncbi_raw.fasta"
out_fa <- "d:/Projects/phylo-platform/r-analysis/data/benchmarks/bacteria_16s/bacteria_16s.fasta"
out_meta <- "d:/Projects/phylo-platform/r-analysis/data/benchmarks/bacteria_16s/metadata.csv"

if (!file.exists(raw)) {
  stop("缺少 NCBI 原始 FASTA: ", raw, call. = FALSE)
}

lines <- readLines(raw, warn = FALSE, encoding = "UTF-8")
lines <- lines[nzchar(trimws(lines))]

recs <- list()
cur_id <- NULL
cur_hdr <- NULL
cur_seq <- character()

flush <- function() {
  if (is.null(cur_id)) return()
  seq <- toupper(paste(cur_seq, collapse = ""))
  seq <- gsub("[^ACGTNRYSWKMBDHV]", "", seq)
  if (nchar(seq) < 200) return()
  recs[[length(recs) + 1]] <<- list(id = cur_id, header = cur_hdr, seq = seq)
}

for (ln in lines) {
  if (startsWith(ln, ">")) {
    flush()
    cur_hdr <- sub("^>", "", ln)
    acc <- strsplit(cur_hdr, "\\s+")[[1]][[1]]
    acc <- sub("\\.[0-9]+$", "", acc)
    cur_id <- gsub("[^A-Za-z0-9_]", "_", acc)
    cur_seq <- character()
  } else {
    cur_seq <- c(cur_seq, gsub("\\s+", "", ln))
  }
}
flush()

seen <- character()
uniq <- list()
for (r in recs) {
  if (r$id %in% seen) next
  seen <- c(seen, r$id)
  uniq[[length(uniq) + 1]] <- r
}
recs <- uniq

message("records=", length(recs))
if (length(recs) < 30) {
  stop("need >=30 sequences, got ", length(recs), call. = FALSE)
}

# 完整 organism 名（用于 environment / resistance 启发式）
organism_of <- function(hdr) {
  t <- sub("^[A-Za-z0-9_.]+\\s+", "", hdr)
  t <- sub(",?\\s*partial sequence.*$", "", t, ignore.case = TRUE)
  t <- sub("\\s*16S ribosomal RNA.*$", "", t, ignore.case = TRUE)
  t <- sub("\\s*\\(.*\\)\\s*$", "", t)
  trimws(t)
}

# taxonomy 环使用属名，避免 1 tip = 1 color 导致图例爆炸
taxonomy_of <- function(hdr) {
  org <- organism_of(hdr)
  # Candidatus Xxx yyy → 保留两词；其余取首词属名
  if (grepl("^Candidatus\\s+", org, ignore.case = TRUE)) {
    parts <- strsplit(org, "\\s+")[[1]]
    return(paste(parts[seq_len(min(2L, length(parts)))], collapse = " "))
  }
  genus <- strsplit(org, "\\s+")[[1]][[1]]
  genus
}

env_for <- function(tax) {
  tl <- tolower(tax)
  if (grepl(
    paste(
      "escherichia|salmonella|klebsiella|shigella|enterococcus|staphylococcus",
      "streptococcus|pseudomonas aeruginosa|acinetobacter|enterobacter|proteus",
      "haemophilus|neisseria|listeria|campylobacter|helicobacter|clostridioides",
      "clostridium difficile|mycobacterium|legionella",
      sep = "|"
    ),
    tl
  )) {
    return("clinical")
  }
  # food 必须先于 soil：lactobacillus 含 bacillus 子串
  if (grepl(
    "lactobacillus|lacticaseibacillus|bifidobacterium|lactococcus|pediococcus|leuconostoc",
    tl
  )) {
    return("food")
  }
  if (grepl("vibrio|alteromonas|shewanella|photobacterium|marinobacter|oceanobacillus", tl)) {
    return("marine")
  }
  if (grepl("cyanobacteria|synechococcus|prochlorococcus|anabaena|nostoc", tl)) {
    return("aquatic")
  }
  if (grepl("thermus|geobacillus|parageobacillus|thermoanaerobacter|aquifex", tl)) {
    return("thermal")
  }
  if (grepl(
    "(^|[^a-z])bacillus|streptomyces|paenibacillus|brevibacillus|priestia|azotobacter|rhizobium|bradyrhizobium|frankia|nitrosomonas|nitrobacter",
    tl
  )) {
    return("soil")
  }
  "environmental"
}

resist_for <- function(tax, env) {
  tl <- tolower(tax)
  if (grepl("staphylococcus aureus|klebsiella|pseudomonas aeruginosa|acinetobacter|enterococcus", tl)) {
    return("MDR_risk")
  }
  if (grepl("escherichia coli|salmonella", tl)) {
    return("AMR_watch")
  }
  if (identical(env, "clinical")) return("unknown")
  "none"
}

dir.create(dirname(out_fa), recursive = TRUE, showWarnings = FALSE)
con <- file(out_fa, open = "wt", encoding = "UTF-8")
meta_rows <- list()
for (r in recs) {
  org <- organism_of(r$header)
  tax <- taxonomy_of(r$header)
  env <- env_for(org)
  writeLines(paste0(">", r$id), con)
  chars <- strsplit(r$seq, "")[[1]]
  chunks <- split(chars, ceiling(seq_along(chars) / 70))
  for (ch in chunks) {
    writeLines(paste(ch, collapse = ""), con)
  }
  meta_rows[[length(meta_rows) + 1]] <- data.frame(
    sample_id = r$id,
    organism_type = "bacteria",
    collection_date = "2020",
    location = "RefSeq",
    host = if (identical(env, "clinical")) "Human" else "NA",
    taxonomy = tax,
    environment = env,
    source = "isolate",
    resistance = resist_for(org, env),
    stringsAsFactors = FALSE
  )
}
close(con)

meta <- do.call(rbind, meta_rows)
utils::write.csv(meta, out_meta, row.names = FALSE, fileEncoding = "UTF-8")
message("wrote ", out_fa, " n=", nrow(meta))
message("wrote ", out_meta)
print(table(meta$environment))
lens <- nchar(vapply(recs, function(x) x$seq, character(1)))
message("seq length: min=", min(lens), " median=", stats::median(lens), " max=", max(lens))
