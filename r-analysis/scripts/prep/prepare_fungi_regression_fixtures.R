# Prepare fungi regression fixtures from benchmark
root <- "d:/Projects/phylo-platform/r-analysis"
fa <- file.path(root, "data/benchmarks/fungi_its/fungi.fasta")
meta <- utils::read.csv(
  file.path(root, "data/benchmarks/fungi_its/metadata.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

lines <- readLines(fa, warn = FALSE, encoding = "UTF-8")
ids <- character()
seqs <- character()
cur_id <- NULL
cur <- character()
flush <- function() {
  if (is.null(cur_id)) return()
  ids <<- c(ids, cur_id)
  seqs <<- c(seqs, toupper(paste(cur, collapse = "")))
}
for (ln in lines) {
  if (!nzchar(trimws(ln))) next
  if (startsWith(ln, ">")) {
    flush()
    cur_id <- sub("^>\\s*", "", ln)
    cur_id <- strsplit(cur_id, "\\s+")[[1]][[1]]
    cur <- character()
  } else {
    cur <- c(cur, gsub("\\s+", "", ln))
  }
}
flush()

take <- 5L
ids5 <- ids[seq_len(take)]
seqs5 <- seqs[seq_len(take)]
meta5 <- meta[match(ids5, meta$sample_id), , drop = FALSE]
if (nrow(meta5) != take || any(is.na(meta5$sample_id))) {
  stop("fixture metadata mismatch", call. = FALSE)
}

write_fa <- function(path, ids_x, seqs_x) {
  out <- character(0)
  for (i in seq_along(ids_x)) {
    out <- c(out, paste0(">", ids_x[[i]]), seqs_x[[i]])
  }
  writeLines(out, path)
}

vdir <- file.path(root, "test-data/fungi/valid")
write_fa(file.path(vdir, "sequences.fasta"), ids5, seqs5)
utils::write.csv(meta5, file.path(vdir, "metadata.csv"), row.names = FALSE)

writeLines(character(0), file.path(root, "test-data/fungi/empty/empty.fasta"))

write_fa(
  file.path(root, "test-data/fungi/illegal_dna/sequences.fasta"),
  ids5[1:3],
  c("ACGTACGTXYZACGT", seqs5[2], seqs5[3])
)
utils::write.csv(
  meta5[1:3, , drop = FALSE],
  file.path(root, "test-data/fungi/illegal_dna/metadata.csv"),
  row.names = FALSE
)

write_fa(
  file.path(root, "test-data/fungi/too_few/sequences.fasta"),
  ids5[1:2],
  seqs5[1:2]
)
utils::write.csv(
  meta5[1:2, , drop = FALSE],
  file.path(root, "test-data/fungi/too_few/metadata.csv"),
  row.names = FALSE
)

mm <- meta5
mm$sample_id[[1]] <- "NOT_A_REAL_TIP"
write_fa(file.path(root, "test-data/fungi/tip_mismatch/sequences.fasta"), ids5, seqs5)
utils::write.csv(mm, file.path(root, "test-data/fungi/tip_mismatch/metadata.csv"), row.names = FALSE)

message("fungi fixtures ready: ", paste(ids5, collapse = ", "))
