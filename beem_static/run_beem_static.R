library(reshape2)
library(beemStatic)
library(tibble)
library(igraph)

# ---- 1. Define the BEEM Processor Function ----
# This part stays outside the loop for efficiency
run_beem_and_save <- function(df_input, output_path) {
  # Data cleaning
  rownames(df_input) <- df_input$Sample
  df_input$Sample <- NULL
  dat.matrix <- t(as.matrix(df_input))

  # Run BEEM - Optimized for your 10-core machine
  res <- func.EM(
    dat = dat.matrix,
    ncpu = 8  # Use 8 cores since you have 10!
  )

  # Process Results
  b <- t(beem2param(res)$b.est) 
  diag(b) <- 0 

  # Filtering
  t.stab <- 0.8
  t.strength <- 0.001
  if(!is.null(res$resample)){
    b[res$resample$b.stab < t.stab] <- 0
  }
  b[abs(b) < t.strength] <- 0

  # Build igraph
  g <- graph_from_adjacency_matrix(b, mode='directed', weighted='I')
  
  # Metadata
  V(g)$label <- rownames(dat.matrix)
  
  # Manual TSS
  tss_matrix <- apply(dat.matrix, 2, function(x) x/sum(x))
  V(g)$RelativeAbundance <- rowMeans(tss_matrix)

  E(g)$Type <- ifelse(E(g)$I > 0, '+', '-')
  E(g)$Strength <- abs(E(g)$I)

  g_simple <- delete_vertices(g, V(g)[degree(g) == 0])
  # ---  Export to GraphML ---
  write_graph(g_simple, file = output_path, format = "graphml")
}

# ---- 2. Define the Main Application Function ----
run_study_analysis <- function(study_name, folder_type) {
  
  percentages <- c(0.30, 0.60, 0.90)
  num_iterations <- 100
  
  base_path <- paste0("beem_static/", study_name, "/", folder_type, "/")

  for (p in percentages) {
    p_int <- as.integer(p * 100)
    
    # Create directories
    out_dir_h <- paste0(base_path, "networks/", p_int, "/healthy/")
    out_dir_u <- paste0(base_path, "networks/", p_int, "/unhealthy/")
    dir.create(out_dir_h, recursive = TRUE, showWarnings = FALSE)
    dir.create(out_dir_u, recursive = TRUE, showWarnings = FALSE)

    cat("\n--- Starting analysis for", p_int, "% of data ---\n")

    for (i in 1:num_iterations) {
      filename <- paste0("sample_", p_int, "_run_", i, ".tsv")
      
      # Load files
      df_healthy <- read.csv(
        paste0(base_path, p_int, "/healthy/", filename), 
        header = TRUE, 
        sep = "\t", 
        check.names = FALSE
      )
      df_unhealthy <- read.csv(
        paste0(base_path, p_int, "/unhealthy/", filename), 
        header = TRUE, 
        sep = "\t",
        check.names = FALSE
      )

      # Define Output Paths
      path_h <- paste0(out_dir_h, "sample_", p_int, "_run_network_healthy_", i, ".graphml")
      path_u <- paste0(out_dir_u, "sample_", p_int, "_run_network_unhealthy_", i, ".graphml")

      # Run BEEM and Export
      run_beem_and_save(df_healthy, path_h)
      run_beem_and_save(df_unhealthy, path_u)

      if (i %% 10 == 0) cat("Iteration", i, "complete...\n")
    }
  }
  cat("\nDone! All networks saved for", study_name, "\n")
}

# ---- 3. RUN THE APP ----
# Simply change these two strings to run different studies
run_study_analysis(study_name = "WANG_ESRD_2020", folder_type = "random_rows")
#run_study_analysis(study_name = "iHMP_IBDMDB_2019", folder_type = "random_rows")
#run_study_analysis(study_name = "YACHIDA_CRC_2019", folder_type = "random_rows")

run_study_analysis(study_name = "WANG_ESRD_2020", folder_type = "random_columns")
run_study_analysis(study_name = "iHMP_IBDMDB_2019", folder_type = "random_columns")
run_study_analysis(study_name = "YACHIDA_CRC_2019", folder_type = "random_columns")
