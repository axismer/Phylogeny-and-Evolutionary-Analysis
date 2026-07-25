# Prepare virus fixtures for Framework v0.2 regression tests.
# Usage: Rscript scripts/prep/prepare_virus_regression_fixtures.R

args_full <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args_full, value = TRUE)
if (length(file_arg) < 1) {
  stop("请用 Rscript 运行本脚本", call. = FALSE)
}
root <- normalizePath(
  file.path(dirname(sub("^--file=", "", file_arg[1])), "..", ".."),
  winslash = "/"
)

src <- file.path(root, "test-data", "fixtures", "h3n2_na_20.fasta")
if (!file.exists(src)) stop("Missing source fasta: ", src, call. = FALSE)

dirs <- list(
  valid = file.path(root, "test-data", "virus", "valid"),
  invalid_fasta = file.path(root, "test-data", "virus", "invalid_fasta"),
  metadata_mismatch = file.path(root, "test-data", "virus", "metadata_mismatch"),
  empty = file.path(root, "test-data", "virus", "empty"),
  too_few = file.path(root, "test-data", "virus", "too_few"),
  illegal_dna = file.path(root, "test-data", "virus", "illegal_dna")
)
for (d in dirs) dir.create(d, recursive = TRUE, showWarnings = FALSE)

lines <- readLines(src, warn = FALSE)
ids <- character()
seqs <- character()
cur_id <- NULL
cur <- character()
flush <- function() {
  if (is.null(cur_id)) return()
  ids <<- c(ids, cur_id)
  seqs <<- c(seqs, paste(cur, collapse = ""))
}
for (ln in lines) {
  if (!nzchar(trimws(ln))) next
  if (startsWith(ln, ">")) {
    if (length(ids) >= 4L) break
    flush()
    cur_id <- sub("^>\\s*", "", ln)
    cur_id <- strsplit(cur_id, "\\s+")[[1]][[1]]
    cur <- character()
  } else if (!is.null(cur_id)) {
    cur <- c(cur, gsub("\\s+", "", ln))
  }
}
flush()
ids <- ids[seq_len(min(4L, length(ids)))]
seqs <- seqs[seq_len(length(ids))]
if (length(ids) < 3L) stop("Need at least 3 sequences for virus fixtures", call. = FALSE)

write_fasta <- function(path, ids, seqs) {
  con <- file(path, "w")
  on.exit(close(con), add = TRUE)
  for (i in seq_along(ids)) {
    writeLines(paste0(">", ids[[i]]), con)
    writeLines(seqs[[i]], con)
  }
}

out_fa <- file.path(dirs$valid, "sequences.fasta")
write_fasta(out_fa, ids, seqs)

writeLines(c("NOT_A_FASTA", "ACGTACGTACGT"), file.path(dirs$invalid_fasta, "bad.fasta"))
file.copy(out_fa, file.path(dirs$metadata_mismatch, "sequences.fasta"), overwrite = TRUE)

# empty: zero-byte file
writeLines(character(0), file.path(dirs$empty, "empty.fasta"))

# too_few: first 2 sequences only
write_fasta(file.path(dirs$too_few, "sequences.fasta"), ids[1:2], seqs[1:2])

# illegal_dna: inject X into first sequence, keep 4 tips
bad_seqs <- seqs
bad_seqs[[1]] <- paste0(substr(seqs[[1]], 1, 20), "XXXX", substr(seqs[[1]], 25, nchar(seqs[[1]])))
write_fasta(file.path(dirs$illegal_dna, "sequences.fasta"), ids, bad_seqs)

meta <- data.frame(
  sample_id = ids,
  organism_type = "virus",
  collection_date = c("2013", "2012", "2009", "2009")[seq_along(ids)],
  location = c("Hawaii", "Boston", "Oregon", "HongKong")[seq_along(ids)],
  host = "human",
  segment = "NA",
  variant = "H3N2",
  stringsAsFactors = FALSE
)
utils::write.csv(meta, file.path(dirs$valid, "metadata.csv"), row.names = FALSE)

meta_bad <- meta
meta_bad$sample_id <- paste0("BAD_", meta_bad$sample_id)
utils::write.csv(meta_bad, file.path(dirs$metadata_mismatch, "metadata.csv"), row.names = FALSE)

message("Virus regression fixtures ready under test-data/virus/")
message("tips: ", paste(ids, collapse = ", "))
