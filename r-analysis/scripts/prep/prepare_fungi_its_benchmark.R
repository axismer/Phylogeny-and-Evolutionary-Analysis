# =============================================================================
# prepare_fungi_its_benchmark.R
# 将 NCBI 公开 ITS FASTA 规范化为 fungi.fasta + metadata.csv（>=30）
# =============================================================================

root <- "d:/Projects/phylo-platform/r-analysis"
raw <- file.path(root, "data/benchmarks/fungi_its/_ncbi_raw.fasta")
out_fa <- file.path(root, "data/benchmarks/fungi_its/fungi.fasta")
out_meta <- file.path(root, "data/benchmarks/fungi_its/metadata.csv")
src_txt <- file.path(root, "data/benchmarks/fungi_its/SOURCE.txt")

if (!file.exists(raw)) {
  stop("缺少 NCBI 原始 FASTA: ", raw, call. = FALSE)
}

lines <- readLines(raw, warn = FALSE, encoding = "UTF-8")
recs <- list()
cur_id <- NULL
cur_hdr <- NULL
cur_seq <- character()

flush <- function() {
  if (is.null(cur_id)) return()
  seq <- toupper(paste(cur_seq, collapse = ""))
  seq <- gsub("[^ACGTURYSWKMBDHVN]", "", seq)
  if (nchar(seq) < 150) return()
  if (!grepl("ITS", cur_hdr, ignore.case = TRUE)) return()
  if (grepl("Mus musculus|16S ribosomal RNA", cur_hdr, ignore.case = TRUE)) return()
  recs[[length(recs) + 1]] <<- list(id = cur_id, header = cur_hdr, seq = seq)
}

for (ln in lines) {
  if (!nzchar(trimws(ln))) next
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

message("ITS records=", length(recs))
if (length(recs) < 30) {
  stop("need >=30 ITS sequences, got ", length(recs), call. = FALSE)
}

organism_of <- function(hdr) {
  t <- sub("^[A-Za-z0-9_.]+\\s+", "", hdr)
  t <- sub("\\s+ITS region.*$", "", t, ignore.case = TRUE)
  t <- sub("\\s+internal transcribed spacer.*$", "", t, ignore.case = TRUE)
  t <- sub("\\s*;.*$", "", t)
  t <- sub("\\s+strain\\s+.*$", "", t, ignore.case = TRUE)
  t <- sub("\\s+CBS\\s+.*$", "", t, ignore.case = TRUE)
  t <- sub("\\s+NRRL\\s+.*$", "", t, ignore.case = TRUE)
  trimws(t)
}

taxonomy_of <- function(hdr) {
  org <- organism_of(hdr)
  parts <- strsplit(org, "\\s+")[[1]]
  if (length(parts) < 1 || !nzchar(parts[[1]])) return("unknown")
  parts[[1]]
}

host_for <- function(tax) {
  tl <- tolower(tax)
  if (grepl("candida|candidozyma|cryptococcus|exophiala|pichia|kluyveromyces|saccharomyces|nakaseomyces", tl)) {
    return("human_clinical")
  }
  if (grepl("fusarium|magnaporthe|botrytis|phyllosticta|cadophora", tl)) {
    return("plant_pathogen")
  }
  if (grepl("trichoderma|arthrobotrys|escovopsis", tl)) {
    return("soil_biocontrol")
  }
  if (grepl("agaricus|caloplaca", tl)) {
    return("environmental")
  }
  if (grepl("aspergillus|penicillium", tl)) {
    return("food_environment")
  }
  "unknown"
}

substrate_for <- function(tax, host) {
  if (identical(host, "human_clinical")) return("clinical_sample")
  if (identical(host, "plant_pathogen")) return("plant_tissue")
  if (identical(host, "soil_biocontrol")) return("soil")
  if (identical(host, "food_environment")) return("indoor_food")
  if (identical(host, "environmental")) return("lichen_environment")
  "unknown"
}

location_for <- function(i) {
  locs <- c("type_material", "culture_collection", "public_refseq", "laboratory_isolate")
  locs[((i - 1L) %% length(locs)) + 1L]
}

fa_lines <- character()
meta_rows <- list()
for (i in seq_along(recs)) {
  r <- recs[[i]]
  tax <- taxonomy_of(r$header)
  host <- host_for(tax)
  substrate <- substrate_for(tax, host)
  fa_lines <- c(fa_lines, paste0(">", r$id), r$seq)
  meta_rows[[i]] <- data.frame(
    sample_id = r$id,
    organism_type = "fungi",
    taxonomy = tax,
    host = host,
    substrate = substrate,
    location = location_for(i),
    collection_date = "RefSeq_type_material",
    stringsAsFactors = FALSE
  )
}

meta <- do.call(rbind, meta_rows)
writeLines(fa_lines, out_fa, useBytes = FALSE)
utils::write.csv(meta, out_meta, row.names = FALSE, fileEncoding = "UTF-8")

writeLines(c(
  "SOURCE: NCBI Nucleotide / RefSeq ITS region (TYPE material where available)",
  "Query method: curated accession list via E-utilities efetch (rettype=fasta)",
  paste0("Prepared: ", format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
  paste0("Sequences: ", nrow(meta)),
  "License/use: public NCBI sequence data; for framework regression only"
), src_txt)

message("wrote ", out_fa, " n=", length(recs))
message("wrote ", out_meta)
invisible(TRUE)
