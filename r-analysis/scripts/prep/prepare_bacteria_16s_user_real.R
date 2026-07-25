# =============================================================================
# prepare_bacteria_16s_user_real.R
# 将 NCBI 下载的真实 16S 整理为「用户数据」形态（FASTA + metadata.csv）
# 不修改建树/可视化算法。
# =============================================================================

raw <- "d:/Projects/phylo-platform/r-analysis/data/real/bacteria_16s_user/_ncbi_download.fasta"
out_fa <- "d:/Projects/phylo-platform/r-analysis/data/real/bacteria_16s_user/sequences.fasta"
out_meta <- "d:/Projects/phylo-platform/r-analysis/data/real/bacteria_16s_user/metadata.csv"
out_src <- "d:/Projects/phylo-platform/r-analysis/data/real/bacteria_16s_user/SOURCE.txt"

if (!file.exists(raw)) {
  stop("缺少下载文件: ", raw, call. = FALSE)
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
if (length(recs) < 20) {
  stop("need >=20 sequences for real-user validation, got ", length(recs), call. = FALSE)
}

organism_of <- function(hdr) {
  t <- sub("^[A-Za-z0-9_.]+\\s+", "", hdr)
  t <- sub(",?\\s*partial sequence.*$", "", t, ignore.case = TRUE)
  t <- sub("\\s*16S ribosomal RNA.*$", "", t, ignore.case = TRUE)
  t <- sub("\\s*\\(.*\\)\\s*$", "", t)
  trimws(t)
}

taxonomy_of <- function(hdr) {
  org <- organism_of(hdr)
  if (grepl("^Candidatus\\s+", org, ignore.case = TRUE)) {
    parts <- strsplit(org, "\\s+")[[1]]
    return(paste(parts[seq_len(min(2L, length(parts)))], collapse = " "))
  }
  strsplit(org, "\\s+")[[1]][[1]]
}

env_for <- function(tax) {
  tl <- tolower(tax)
  if (grepl(
    paste(
      "escherichia|salmonella|klebsiella|shigella|enterococcus|staphylococcus",
      "streptococcus|pseudomonas aeruginosa|acinetobacter|enterobacter",
      sep = "|"
    ),
    tl
  )) {
    return("clinical")
  }
  if (grepl("lactobacillus|lacticaseibacillus|bifidobacterium|lactococcus|pediococcus", tl)) {
    return("food")
  }
  if (grepl("vibrio|alteromonas|shewanella|photobacterium|marinobacter|roseobacter", tl)) {
    return("marine")
  }
  if (grepl("thermus|geobacillus|parageobacillus|thermoanaerobacter", tl)) {
    return("thermal")
  }
  if (grepl(
    "(^|[^a-z])bacillus|streptomyces|paenibacillus|brevibacillus|priestia",
    tl
  )) {
    return("soil")
  }
  "environmental"
}

resist_for <- function(org, env) {
  tl <- tolower(org)
  if (grepl("staphylococcus aureus|klebsiella|pseudomonas aeruginosa|enterococcus", tl)) {
    return("MDR_risk")
  }
  if (grepl("escherichia coli|salmonella", tl)) {
    return("AMR_watch")
  }
  if (identical(env, "clinical")) return("unknown")
  "none"
}

# 用户风格 sample_id：S001.. 同时在 metadata 保留 accession 便于溯源
dir.create(dirname(out_fa), recursive = TRUE, showWarnings = FALSE)
con <- file(out_fa, open = "wt", encoding = "UTF-8")
meta_rows <- list()
for (i in seq_along(recs)) {
  r <- recs[[i]]
  sid <- sprintf("S%03d", i)
  org <- organism_of(r$header)
  tax <- taxonomy_of(r$header)
  env <- env_for(org)
  writeLines(paste0(">", sid), con)
  chars <- strsplit(r$seq, "")[[1]]
  chunks <- split(chars, ceiling(seq_along(chars) / 70))
  for (ch in chunks) {
    writeLines(paste(ch, collapse = ""), con)
  }
  meta_rows[[length(meta_rows) + 1]] <- data.frame(
    sample_id = sid,
    organism_type = "bacteria",
    accession = r$id,
    collection_date = "2024",
    location = "NCBI_RefSeq",
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

src <- c(
  "Bacteria real-user 16S validation dataset",
  paste0("Downloaded: ", Sys.Date()),
  "Source: NCBI Nucleotide (RefSeq 16S rRNA) via E-utilities efetch",
  "Endpoint: https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi",
  paste0("n_sequences: ", nrow(meta)),
  "FASTA tip labels: user-style sample_id (S001..)",
  "metadata sample_id must match FASTA headers 1:1",
  "Required pipeline columns: sample_id, taxonomy, environment, source, resistance",
  "Note: resistance is schema-required by BacteriaStrategy; derived from organism heuristics."
)
writeLines(src, out_src)

message("wrote ", out_fa, " n=", nrow(meta))
message("wrote ", out_meta)
print(table(meta$environment))
lens <- nchar(vapply(recs, function(x) x$seq, character(1)))
message("seq length: min=", min(lens), " median=", stats::median(lens), " max=", max(lens))
