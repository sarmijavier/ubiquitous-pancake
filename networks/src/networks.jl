module networks
import FlashWeave
using CSV
using DataFrames


# Read the TSV file into a DataFrame
df = CSV.read("your_file.tsv", DataFrame, delim='\t')

# Display the first few rows
view(df)




end # module networks
