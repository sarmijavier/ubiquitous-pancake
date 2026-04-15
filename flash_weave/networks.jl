using CSV
using DataFrames
using FlashWeave
using Logging

# ---- 1. Define the FlashWeave Processor Function ----
function run_flash_weave_and_save(df_input, output_path)
    # Ensure data is treated as a Matrix for FlashWeave
    # We drop the first column (Sample names) if it exists
    #data_cols = names(df_input)[2:end] 
    #data_matrix = Matrix(df_input[:, 2:end])

    try
        net = FlashWeave.learn_network(
            df_input,
            sensitive=true,
            heterogeneous=false
        )
        # FlashWeave saves to edgelist by default
        FlashWeave.save_network(output_path, net)
    catch e
        @error "FlashWeave failed for $output_path" exception=(e, catch_backtrace())
    end
end

# ---- 2. Define the Main Application Function ----
function run_study_analysis(study_name, folder_type)
    percentages = [0.30, 0.60, 0.90]
    num_iterations = 100
    
    base_path = "./beem_static/$study_name/$folder_type/"
	base_path_output = "./flash_weave/$study_name/$folder_type/"

    for p in percentages
        p_int = Int(p * 100)
        
        # Create output directories for networks
        out_dir_h = "$(base_path_output)networks/$p_int/healthy/"
        out_dir_u = "$(base_path_output)networks/$p_int/unhealthy/"
        mkpath(out_dir_h)
        mkpath(out_dir_u)

        println("\n--- Starting analysis for $p_int% of data in $study_name ---")

        for i in 1:num_iterations
            filename = "sample_$(p_int)_run_$i.tsv"
            
            # Construct Input Paths (Mirroring your R logic)
            path_in_h = "$(base_path)$p_int/healthy/$filename"
            path_in_u = "$(base_path)$p_int/unhealthy/$filename"

            # Construct Output Paths
            path_out_h = "$(out_dir_h)sample_$(p_int)_run_network_healthy_$i.edgelist"
            path_out_u = "$(out_dir_u)sample_$(p_int)_run_network_unhealthy_$i.edgelist"

            try
                # Load Healthy
                if isfile(path_in_h)
                    df_h = CSV.read(path_in_h, DataFrame, delim='\t')
                    run_flash_weave_and_save(path_in_h, path_out_h)
                else
                    @warn "File missing: $path_in_h"
                end

                # Load Unhealthy
                if isfile(path_in_u)
                    df_u = CSV.read(path_in_u, DataFrame, delim='\t')
                    run_flash_weave_and_save(path_in_u, path_out_u)
                else
                    @warn "File missing: $path_in_u"
                end

            catch e
                @error "Error processing iteration $i for p=$p_int" exception=(e, catch_backtrace())
            end

            if i % 10 == 0
                println("Iteration $i complete...")
            end
        end
    end
    println("\nDone! All networks saved for $study_name")
end

# ---- 3. RUN THE APP ----


studies = ["WANG_ESRD_2020", "iHMP_IBDMDB_2019", "YACHIDA_CRC_2019"]
folder_types = ["random_rows", "random_columns"]

for study in studies
    for f_type in folder_types
        run_study_analysis(study, f_type)
    end
end