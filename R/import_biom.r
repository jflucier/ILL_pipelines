# if (!require("BiocManager", quietly = TRUE))
#   install.packages("BiocManager")
# 
# BiocManager::install("phyloseq")



library(phyloseq)
biom_file <- "/storage/Documents/service/biologie/laforest-lapointe/analysis/20240125_trnL_db/kraken_k2_nt/all_reports.new.biom"
tree_file <- "/storage/Documents/service/biologie/laforest-lapointe/analysis/20240125_trnL_db/kraken_k2_nt/tax_report.nwk"
sampledata <- "/storage/Documents/service/biologie/laforest-lapointe/analysis/20240125_trnL_db/kraken_k2_nt/metadata.tsv"
# test <- read_tree(
#   tree_file,
#   errorIfNULL=TRUE
# )

biom_otu_tax <- import_biom(
  biom_file,
  # treefilename = x
)

meta <- import_qiime_sample_data(sampledata)
phylo <- merge_phyloseq(biom_otu_tax, meta)


