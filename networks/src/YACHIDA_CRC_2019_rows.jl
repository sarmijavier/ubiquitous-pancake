import FlashWeave
using CSV
using DataFrames
using StatsBase, Random

df_main_meta = CSV.read("processed_data/YACHIDA_CRC_2019/metadata.tsv", DataFrame, delim='\t')

metadata_small = select(df_main_meta, :Sample, :"Study.Group")
# Create a column for each unique value in Study.Group
meta_sub = select(df_main_meta, :Sample, :"Study.Group")
# One-Hot Encode "Healthy" (1 if Healthy, 0 if not)
meta_sub.is_healthy = [g == "Healthy" ? 1 : 0 for g in meta_sub[: , :"Study.Group"]]

meta_sub = select(meta_sub, :Sample, :is_healthy)

#percentages = [0.30, 0.60, 0.90]
percentages = [0.90]
num_iterations = 100

for p in percentages
    p_int = Int(p * 100)
    for i in 50:num_iterations
        filename = "sample_$(p_int)_run_$i.tsv"
        
        try
            # 1. Carga de datos
            path = "networks/YACHIDA_CRC_2019/random_rows/$(p_int)/$(filename)"
            df = CSV.read(path, DataFrame, delim='\t')	
            combined_df = leftjoin(df, meta_sub, on = :Sample)

            # 2. Preprocesamiento
            df_healthy = filter(row -> row.is_healthy == 1, combined_df)
            df_unhealthy = filter(row -> row.is_healthy == 0, combined_df)

            # Es buena práctica verificar si quedaron filas antes de pasar a FlashWeave
            if nrow(df_healthy) < 2 || nrow(df_unhealthy) < 2
                @warn "Poco volumen de datos en iteración $i (p=$p). Saltando..."
                continue
            end

            select!(df_healthy, Not(:is_healthy, :Sample))
            select!(df_unhealthy, Not(:is_healthy, :Sample))
            
            # 3. Aprendizaje de Redes (Punto crítico de falla)
            # --- Healthy ---
            try
                healthy = FlashWeave.learn_network(
                    Matrix(df_healthy),
                    sensitive=true,
                    heterogeneous=false
                )
                filename_net_h = "sample_$(p_int)_run_network_healthy_$i.edgelist"
                FlashWeave.save_network("networks/YACHIDA_CRC_2019/random_rows/networks/$(p_int)/$(filename_net_h)", healthy)
            catch e
                @error "Fallo en FlashWeave (Healthy) - p: $p, run: $i" exception=(e, catch_backtrace())
            end

            # --- Unhealthy ---
            try
                unhealthy = FlashWeave.learn_network(
                    Matrix(df_unhealthy),
                    sensitive=true,
                    heterogeneous=false
                )
                filename_net_u = "sample_$(p_int)_run_network_unhealthy_$i.edgelist"
                FlashWeave.save_network("networks/YACHIDA_CRC_2019/random_rows/networks/$(p_int)/$(filename_net_u)", unhealthy)
            catch e
                @error "Fallo en FlashWeave (Unhealthy) - p: $p, run: $i" exception=(e, catch_backtrace())
            end

        catch e
            # Este catch captura errores generales (archivo no encontrado, errores de join, etc.)
            @error "Error general en iteración $i para p=$p" exception=(e, catch_backtrace())
            continue # Salta a la siguiente iteración (i+1)
        end
    end
end