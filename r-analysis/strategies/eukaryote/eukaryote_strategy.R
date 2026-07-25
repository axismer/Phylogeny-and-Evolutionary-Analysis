# =============================================================================
# eukaryote_strategy.R — EukaryotePhyloStrategy（接口骨架）
# =============================================================================

create_eukaryote_strategy <- function() {
  if (!exists("eukaryote_annotation_config", mode = "function")) {
    dirs <- .get_framework_dirs()
    source(file.path(dirs$strategies, "eukaryote", "eukaryote_annotation.R"), local = FALSE)
  }

  new_phylo_strategy(
    organism_type = "eukaryote",

    validate_input = function(ctx) {
      if (is.null(ctx$fasta_path) || !file.exists(ctx$fasta_path)) {
        stop("EukaryoteStrategy: FASTA 无效或不存在", call. = FALSE)
      }
      invisible(TRUE)
    },

    parse_metadata = function(ctx) {
      if (is.null(ctx$metadata_path) || !nzchar(ctx$metadata_path)) return(NULL)
      if (exists("validate_metadata_file", mode = "function")) {
        validate_metadata_file(ctx$metadata_path, organism_type = "eukaryote")
      }
      utils::read.csv(ctx$metadata_path, stringsAsFactors = FALSE, check.names = FALSE)
    },

    tree_params = function(ctx) default_tree_params("eukaryote"),
    annotation_config = function(ctx) eukaryote_annotation_config(ctx),
    output_spec = function(ctx) default_output_spec("eukaryote"),

    run = function(ctx) {
      result <- build_analysis_result(
        status = "not_implemented",
        organism_type = "eukaryote",
        statistics = list(
          message = "EukaryotePhyloStrategy 仅完成接口骨架。",
          required_files = c(
            "strategies/eukaryote/eukaryote_strategy.R (run)",
            "strategies/eukaryote/eukaryote_annotation.R"
          )
        )
      )
      if (!is.null(ctx$output_dir) && nzchar(ctx$output_dir)) {
        if (!dir.exists(ctx$output_dir)) {
          dir.create(ctx$output_dir, recursive = TRUE, showWarnings = FALSE)
        }
        write_analysis_result(result, ctx$output_dir)
      }
      result
    }
  )
}
