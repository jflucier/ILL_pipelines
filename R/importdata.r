library("pacman")
p_load(data.table, kableExtra, mgsub, phyloseq, tidyverse,
              trust, lubridate, vegan, magrittr)

################################################################################
### Import, Tidy, Subset & Export Data #########################################
#######################################################O########O###############
### Author: Jonathan Rondeau-Leclaire #####################..###################
########################################################\######/################
### Last Modifications: March 19th, 2023  ###############\____/#################
################################################################################

# This script was designed to IMPORT all data from a clinical study in which
# two types of samples were collected at two points in time from each participant,
# the samples sequenced and the various abundance tables created. It was written
# and optimized for use with the output of the reference-based (i.-e not assembly)
# methods from this pipeline : https://github.com/jflucier/ILL_pipelines.

# This script EXPORTS phyloseq objects and the tables used in their fabrication.
# It is designed to subset the data by sample type (here, saliva and fecal) and
# create a separate object for sequenced Mock communities, which are not
# longitudinal, have no associated Participants Data, and are treated separately.

# This script uses 4 types of RAW DATA, namely Participants and Samples data, and
# both functional and taxonomic abundance tables. It allows independently using
# merged abundance tables from 3 different taxonomic classifiers, namely Sourmash,
# MetaPhlAn, and the Kraken/Bracken combo; and the HUMAnN functional profiler,
# here optimized for pathway abundance but easily adapted to gene families.

# The script also OUTPUTS several interpretable sanity checks and summary stats
# in the console. It makes extensive use of dplyr/tidyverse syntax and runs a
# ~50 samples study with ~1000 species in a few minutes using 2 cores.

# The script layout is as follows:

# 01. Samples & Participants Data
# 02. MPA-style Taxonomy tables
# 03. MetaPhlAn & Kraken/Bracken Abundance Tables
# 04. SourMash Taxonomy Table
# 05. SourMash Abundance Table
# 06. Pathway Abundance Table
# 07. Taxonomy Metadata
# 08. Data Subsetting
# 09. Summary Statistics
# 10. Sanity Checks
# 11. Phyloseq Objects & Data Export
# 12. Participants & Samples Data Summary Tables

####################################···
#### Samples & Participants Data ####···
####################################···

samplesPath = "data/provid19_sample_metadata.csv"
partPath = "data/provid19_participants_data.csv"
# Factor levels desired (will help with plotting later on), by study group :
partLvls = c("02","06","10","15","17","18","20","31","11","13","19","22","25","LD")
fluProPath = "data/flupro_provid19_local.csv"
treatLvls = c("start","end")

### We compute the flu-pro score for each participant entry
fluPro <- read_csv2(fluProPath) %>%
  dplyr::filter(event_name!="Questionnaire santé") %>%
  mutate(JDB = str_replace_all(event_name, "JDB ",""),
         .keep = "unused") %>%
  mutate(partID = as.factor(str_pad(ID,2,"left","0")), # format the partID with leading 0
         .keep="unused") %>%
  mutate(entryDate = as.Date(entry_date,"%d.%m.%y"),  # format entry date
         .keep="unused") %>%
  mutate(fluPro = rowSums(across(where(is.numeric)), # compute score
                          na.rm=TRUE),.keep="unused")

fluPro$JDB %<>% as.numeric # for some reason, causes problem if integrated in mutate()

### We tidy the table containing samples data
sampDataProv <- read_csv2(samplesPath) %>%
  filter(sampID!= "MSA-3001") %>% # remove mock community, but keep LD samples
  mutate_if(is.character, as.factor) %>%
  mutate(sampDate = as.Date(sampDate,"%d.%m.%y")) %>%
  mutate(storageTime = as.numeric(as.Date("2022-05-24")-sampDate)) %>% # compute storage time
      # on 2022-05-26 we were informed the librairies were ready, precise date might differ
  group_by(partID,compart) %>%          # operate at a subgroup level
  mutate(treatDay = max(sampDate)) %>%  # highest date per subgroup printed in new variable
  mutate(treatDay = case_when(     # change variable depending wether:
    treatDay == sampDate & partID!="LD"~'end',   # max date is same as sampDate, or
    treatDay > sampDate & partID!="LD"~'start'     # it's not
  )) %>% mutate(treatDay = factor(treatDay,levels = treatLvls)) %>%
  mutate(partID = str_pad(partID,2,"left","0")) %>%
  mutate(partID = factor(partID, levels = partLvls)) %>%
  arrange(partID, compart) %>% # always nice when samples are ordered (:
  ungroup

#   # !!!! flupro score are only with matching dates... weighed average required for "end"?
#   # +++++++ Prov-LD will require having 4 time points!
#!!! LD samples will only be kept in the master (xProvX) datasets. The subsetting will remove them.

metaMock <- read_csv2(samplesPath) %>%
  filter(sampID == "MSA-3001") %>% # do you have ANY IDEA the havoc a hyphenated name can wreak?!
  mutate(sampID = replace(sampID,sampID == "MSA-3001","MSA_3001")) %>%
  tibble::column_to_rownames("sampID")

### We compute the mean fluPro score for each participant, defined as the
### mean of fluPro scores up to the day before next sampling date (or last sampling date)

# List will be populated by looping through partIDs and sampling compartments.
# Not very elegant, but it works.

myList <- list()
count = 1 # for list indexation

for (i in partLvls){
  if(i=="LD"){next} # no fluPro scores for PROVID-LD samples

  FP <- dplyr::filter(fluPro, partID==i) %>% as.data.frame

  for (j in unique(sampDataProv$compart)) {

    sampDates <- sampDataProv %>%               # extract all sampling dates
      dplyr::filter(partID==i & compart==j) %>% # for current partID & compart
      arrange(sampDate) %$% sampDate            # "expose" colnames to call values

      int1 <- interval(sampDates[1], sampDates[2]-1) # up to one day before next sampDate

      myList[[count]] <- data.frame(          # add a small df to list
        FP %>% mutate(treatDay = case_when(   # recreate treatDay variable
          entryDate %within% int1 ~ "start",  # first interval
          TRUE ~ "end")) %>%                  # outside (beyond) interval
        group_by(treatDay) %>%                # to use summarise
        summarise(meanFP = mean(fluPro)),     # compute mean fluPro score
        compart=j, partID = i)                # add partID and compart to df

      count = count+1   # update count
  }
}

### Generalization: here's a place to start when many intervals are required :
#      for (k in 1:length(sampDates)-1) {
#      assign(paste0("int",k), interval(sampDates[k],sampDates[k+1]))
#      }

sampDataProv %<>% # update the samples data table
  left_join(rbindlist(myList) %>% tibble,  # create DF from list of DFs
            by = c('partID', 'compart', 'treatDay')) # unique matches

### We tidy the table containing the participants demographic and clinical data
partDataProv <- read_csv2(partPath) %>%
  mutate_if(is.character, as.factor) %>%
  mutate(BMI_group = as.factor(case_when( # create BMI group variable :
    BMI<18.5~'UW',
    BMI>= 18.5 & BMI<25 ~'HW',
    BMI>= 25 & BMI<30 ~'OW',
    BMI>= 30~'OB'))) %>%
  mutate(partID = str_pad(partID,2,"left","0")) %>% # format the partID with leading 0
  mutate(partID = factor(partID, levels = partLvls)) %>% # order some factor levels
  mutate(lostSmell = factor(lostSmell, levels = c("Y","N"))) %>%
  arrange(partID)

str(sampDataProv)
str(partDataProv)

##################################···
#### MPA-style Taxonomy tables ####···
##################################···
# Works for MetaPhlAn (MPA) output, and Kraken-Bracken (KB) output that's been
# converted to MPA-style table. The latter can be generated using KrakenTools.

### DEFINE required taxonomic levels according to your input table (see Bracken)
taxNames <- c("Kingdom","Phylum","Class","Order","Family","Genus","Species"
              )  # comment before the comma following the lowest level available

taxCodes <- c("\\|p__", "\\|c__", # selects relevant codes (metaphlan-formatting)
              "\\|o__", "\\|f__", "\\|g__", "s__")[1:length(taxNames)-1]

inKB = "data/species_PROVID19_conf0_1.tsv"
inMPA = "data/provid19_MPA_abundance.tsv"

### We break apart MPA-like taxonomy to create one column per level
### We'll make this a function to re-use it for the MetaPhlAn table

tax.breaker <- function(infile) {
  tmp <- read_tsv(infile, col_select = 1)
  tmp[,taxNames] <- NA # create one empty column per taxonomic level
  for (i in 1:dim(tmp)[1]) {
    if (length(str_split(tmp[i,1],"k__")[[1]])>2) { # if row has >1 kingdom it will create >2 strings
      tmp[i,2] = paste0(str_split(tmp[i,1], "k__")[[1]][2],
                       str_split(str_split(tmp[i,1],"k__")[[1]][3], "\\|[a-z]__")[[1]][1])}
    else {str_split(str_split(tmp[i,1],"k__")[[1]][2],"\\|[a-z]__")[[1]][1] -> tmp[i,2]}
    colnum = 3; for (j in taxCodes) {
      if (j == "s__") {str_split(tmp[i,1],"s__")[[1]][2] -> tmp[i,8]}
      else {x = length(str_split(tmp[i,1],"k__")[[1]])
      str_split(str_split(str_split(tmp[i,1],"k__")[[1]][x],j)[[1]][2],"\\|[a-z]__")[[1]][1]->tmp[i,colnum]
      colnum = colnum+1 # started with the 3rd column, increases +1 with every loop
      }
    }; remove(colnum,x,i,j)
  }; tmp[,1:length(tmp)] %<>% lapply(as.factor)

  tmp %>% mutate(dummy = Species) %>%
    dplyr::select(-1) %>%
    column_to_rownames("dummy") %>%
    as.matrix
}
taxProvKB <- tax.breaker(inKB) # Kraken-Bracken MPA-style output
taxProvMPA <- tax.breaker(inMPA)

######################################################···
#### MetaPhlAn & Kraken/Bracken Abundance Tables ####···
######################################################···

#!!!!! We need to use the bowtie2 out to estimate the sequence count from
#!!!!! this relative abundance table

abund.fun <- function(infile,mock) {
  tmp <- read_tsv(infile) %>%
    separate(col = "#Classification", into = c("#Classification","Species"),sep = "\\|s__") %>%
    as.data.frame %>%
    column_to_rownames("Species") %>% # lowest tax level as rownames
    dplyr::select(-c("#Classification"))

  colnames(tmp) %<>% gsub(x = .,pattern = "-",replacement = "_") # replace hyphen in sample names

  tmp %>% ###! purrr requires explicit "." to pipe!
    purrr::when(mock == T ~ dplyr::select(.,"MSA_3001"), # LHS=condition, RHS=function to perform
                ~ dplyr::select(.,sampDataProv$sampID)) %>%
    filter(rowSums(across(where(is.numeric)))!= 0) %>%
    as.data.frame # Taxa classification is used as row name (otu_mat in tuto)
}###! add list of mock communities

countsProvMPA <- abund.fun(inMPA, mock = F)
countsMockMPA <- abund.fun(inMPA, mock = T)
countsProvKB <- abund.fun(inKB, mock = F)
countsMockKB <- abund.fun(inKB, mock = T)

### We remove taxa not in abundance table. Warning, do Mock first !
taxMockKB <- taxProvKB[rownames(countsMockKB),]
taxMockMPA <- taxProvMPA[rownames(countsMockMPA),]
taxProvKB <- taxProvKB[rownames(countsProvKB),]
taxProvMPA <- taxProvMPA[rownames(countsProvMPA),]

################################···
#### SourMash Taxonomy Table ####···
################################···
# Sourmash's output table is completely different from MPA!

abundPathSM = "data/lineages_k51_genebank_full/*.csv" # abundance table from Sourmash
# abundPathSM = "./lineages_k21_gtdb/*.csv" # other options ...
taxoSM <- c("Domain", "Phylum", "Class", "Order", "Family", "Genus", "Species","Strains")
rename.fun <- function(x) {str_remove(x,".__")} #we'll remove the p__ occurence in taxa
### read in the sourmash taxonomy results from all samples into a single data frame

###! Using non-summarised SM output we format the raw table
rawSM <- Sys.glob(abundPathSM) %>% # *** SM for SourMash
  map_dfr(read_csv, col_types = "ddddddddcccddddcccdc") %>%
  separate(lineage, into = taxoSM, sep = ";", fill = "right") %>%
  mutate_at(taxoSM,rename.fun) %>% # we call renameFun defined above
  select_if(~sum(!is.na(.)) > 0) %>% # drop Strain column if it's empty (depends on ref db)
  mutate(uniqueK = (unique_intersect_bp/scaled)*average_abund, # calculate relative abundance
         query_name = replace(query_name,query_name == "MSA-3001","MSA_3001"),
         Species = gsub(" ","_",Species), #create a dummy variable, because next function will eat it up
         Species = gsub("\\.","",Species))

### We first use this last table to create a list of all species present in our samples.
### This command will REMOVE ALL STRAINS and only keep species info***
taxProvSM <- rawSM %>% # table with all samples present in metadata
  filter(query_name %in% sampDataProv$sampID) %>% # keep relevant observations only
  dplyr::select(taxoSM[1:7]) %>% distinct %>% # ***select unique SPECIES
  mutate(dummy = Species) %>% #create a dummy variable, because next function will eat it up
  column_to_rownames("dummy") %>% # you hungry little function! eat my column and be gone!
  as.matrix

### we also need to study the mock community separately, identical except for...
taxMockSM <- rawSM %>%
  filter(query_name == "MSA_3001") %>% # ...this line !
  dplyr::select(taxoSM[1:7]) %>% distinct %>%
  mutate(dummy = Species) %>% column_to_rownames("dummy") %>%
  as.matrix

###! Using summarised output could look like this...
#rawSM <- Sys.glob(abundPathSM) %>% # *** SM for SourMash
#  map_dfr(read_csv, col_types = "ccdcccddc")
###! further adaptations needed, not solved at all, see https://github.com/sourmash-bio/sourmash/issues/2289

#################################···
#### SourMash Abundance Table ####···
#################################···

rawSMcounts <- rawSM %>%
  group_by(query_name,Species) %>%
  summarise(uniqueK = sum(uniqueK)) %>%    # sum-up unique k-mers of strains from a same species
  dplyr::select(query_name, Species, uniqueK) %>%  # select columns of interest
  pivot_wider(id_cols = Species, names_from = query_name, values_from = uniqueK) %>% # transform to wide format
  replace(is.na(.), 0) %>% # replace all NAs with 0
  column_to_rownames("Species") %>% # sample name assigned to row name
  round(digits=0) # rounding off sequence counts that have decimals...
                  # some tools we'll use later on don't like these, such as breakaway/DivNet

countsProvSM <- rawSMcounts %>%
  dplyr::select(sampDataProv$sampID) %>% # make sure we have the right samples
  .[,sampDataProv$sampID] %>%  #reorder the table
  .[rowSums(.)>0,] #and no taxa is absent from all samples

# Let's do the same for the Mock community :
countsMockSM <- rawSMcounts %>%
  dplyr::select("MSA_3001") %>%
  filter(MSA_3001>0)#and no taxa is absent from all samples

################################···
#### Pathway Abundance Table ####···
################################···

### We'll do some formatting first
rawMC <- read_tsv("data/humann_samples_table.tsv") %>%
  select(-contains("MSA")) %>% # no need for mock communities here
  dplyr::rename(pathway = '# Pathway') %>% # oooh we don't like spaces in column names.
  mutate(pathID = str_split(pathway,":", simplify=T)[,1]) %>% # we want to split the name of the pathway
  mutate(pathDesc = str_split(pathway,": ", simplify=T)[,2]) %>%
  dplyr::select(-pathway) %>%
  mutate(pathID = gsub(" ","_",pathID)) %>%   # Some string manip to avoid errors with feature names
  mutate(pathID = gsub("-","_",pathID)) %>%
  mutate(pathID = gsub("\\+","_",pathID)) %>%
  column_to_rownames("pathID")

names(rawMC) %<>% gsub("_Abundance","",.) # rename the headers

### We create an abundance table where pathways are rows
countsProvMC <- rawMC %>%
  select(-pathDesc) %>%
  .[rowSums(.)>0,] # remove taxa absent from all samples

### And we create a taxonomy list, which simply uses pathID as rownames
### and pathDesc as single column. That will mostly be useful for ps objects
pathProvMC <- rawMC %>% select(pathDesc) %>% as.matrix

#########################···
#### Samples Metadata ####···
#########################···

### This function counts how many taxa are >1% abundance by sample
pa.fun <- function(classifier) {
  paste0("countsProv",classifier) %>% get %>% # <<< lil'trick to run over similarly named objects
  # assign 1 to taxa with >1% (0.01) of sample sequence counts:
    mutate_all(~if_else(.x/sum(.x)>0.01,1,0)) %>%
  # count the frequency of these taxa by sample:
    summarise_all(sum) %>% t %>% as.data.frame %>%
    setnames(paste0("abund",classifier)) %>% # create unique variable names
    rownames_to_column(var="sampID") # so we can use joining functions (below)
}

### We take this opportunity to merge the participants data with the
### samples data to create the table that will serve the subsequent analyses.
metaProv <- sampDataProv %>% # for all 53 samples,add associated participant data:
  full_join(partDataProv, by="partID") %>% # and then the taxa count
  list(., pa.fun("SM"), pa.fun("MPA"), pa.fun("KB")) %>% # using a list
  plyr::join_all(by='sampID',type='full') %>% # which we can feed to join_all!
  column_to_rownames("sampID")

########################···
#### Data Subsetting ####····
########################···

# In this study, participants sampled 2 different comparts (Saliva and Feces)
# which we will be analysing (mostly) independently. We subset the data accordingly.
  ### DEFINE required number of samples per partID per compart :
  #reqSamples = 2 # in PROVID-19, particpants were expected to sample each compart twice
    #!! we'll keep them for now!!!

samplesFeces <- metaProv %>%
  dplyr::filter(compart == "F" & partID!= "LD") %>% rownames # LD samples are omitted from the subsets
#  group_by(partID) %>% # grouping makes next operation work on group level
#  dplyr::filter(n() == reqSamples) %>% # filters out patient 22 who only has 1 fecal sample
#  ungroup %>%
#  distinct(sampID) %>% pull # "pull" the list of their sampID

samplesSaliva <- metaProv %>% filter(compart == "S" & partID!= "LD") %>% rownames


### Then, we subset the counts accordingly, and drop taxa absent* from all samples:
countsSalivaKB <- countsProvKB[,samplesSaliva] %>% # subset for required samples
  .[rowSums(.)>0,] # min all-samples count required by taxa, MUST BE at least >0 !
countsFecesKB <- countsProvKB[,samplesFeces] %>%.[rowSums(.)>0,]
countsSalivaSM <- countsProvSM[,samplesSaliva] %>% .[rowSums(.)>0,]
countsFecesSM <- countsProvSM[,samplesFeces] %>% .[rowSums(.)>0,]
countsSalivaMC <- countsProvMC[,samplesSaliva] %>% .[rowSums(.)>0,]
countsFecesMC <- countsProvMC[,samplesFeces] %>% .[rowSums(.)>0,]
countsSalivaMPA <- countsProvMPA[,samplesSaliva] %>% .[rowSums(.)>0,]
countsFecesMPA <- countsProvMPA[,samplesFeces] %>% .[rowSums(.)>0,]

### using this counts table, we subset the taxonomy to match the subset & filtered counts tables:
taxSalivaKB <- taxProvKB[rownames(countsSalivaKB),]
taxFecesKB <- taxProvKB[rownames(countsFecesKB),]
taxSalivaSM <- taxProvSM[rownames(countsSalivaSM),]
taxFecesSM <- taxProvSM[rownames(countsFecesSM),]
taxSalivaMPA <- taxProvMPA[rownames(countsSalivaMPA),]
taxFecesMPA <- taxProvMPA[rownames(countsFecesMPA),]
pathSalivaMC <- pathProvMC[rownames(countsSalivaMC),] %>% as.matrix
pathFecesMC <- pathProvMC[rownames(countsFecesMC),] %>% as.matrix

### and we subset the samples data table
metaFeces <- metaProv[samplesFeces,] %>% droplevels
metaSaliva <- metaProv[samplesSaliva,] %>% droplevels

############################···
#### Summary Statistics ####····
############################···

### We plot the (log) distribution of total counts per taxa
countsProvKB %>% rowSums %>% sort %T>% # the %T>% pipes to the next TWO functions
  plot(log = "y", xlim = c(0,length(countsProvKB[,1])), ylim = c(1,max(.)),
       main = "distribution of sequence counts per taxa (Kraken/Bracken)") %>%
  summary # and get some statistics on the number of sequences per taxa

countsProvSM %>% rowSums %>% sort %T>%
  plot(log = "y", xlim = c(0,length(countsProvSM[,1])), ylim = c(1,max(.)),
       main = "distribution of sequence counts per taxa (SourMash)") %>% summary

countsProvMPA %>% rowSums %>% sort %T>%
  plot(log = "y", xlim = c(0,length(countsProvMPA[,1])), ylim = c(1,max(.)),
       main = "distribution of sequence counts per taxa (MetaPhlAn)") %>% summary

countsProvMC %>% rowSums %>% sort %T>%
  plot(log = "y", xlim = c(0,length(countsProvMC[,1])), ylim = c(1,max(.)),
       main = "distribution of sequence counts per pathway (MetaCyc)") %>% summary

countsFecesSM %>% colSums %>% as.data.frame %>% summarise(mean = mean(.),sd = sd(.))
countsFecesKB %>% colSums %>% as.data.frame %>% summarise(mean = mean(.),sd = sd(.))
countsFecesMPA %>% colSums %>% as.data.frame %>% summarise(mean = mean(.),sd = sd(.))
  # As you can see, MPA values are normalised to 100

### The following function prints a few descriptive statistics in your console
sumStats.fun <- function(x) {
  taxaPA <- apply(decostand(x, method = "pa"), 1, sum)
  message("Dataset has ",dim(x)[1]," features and ",dim(x)[2]," samples.")
  message(x[which(taxaPA == ncol(x)),] %>% rownames %>% length,
          " features appear in all samples")
  message(x[which(taxaPA<dim(x)[2]/2),] %>% rownames %>% length,
          " are found in fewer than half the samples")
  message(x[which(taxaPA<= 2),] %>% rownames %>% length,
          " are found in 2 or fewer samples")
  message("Distribution of raw counts per sample :")
    x %>% apply(2,sum) %>% sort %T>% # We plot the distribution of total counts per sample
      plot(.,xlim = c(0,length(.)),ylim = c(min(.),max(.))) %>% summary %>% print
  message("Number of features per sample :")
    apply(decostand(x, method = "pa"), 2, sum) %>% summary            %>% print
  message("Number of samples each features appears in:")
    taxaPA %>% summary                                              %>% print
} # invoke the function on your counts datasets :
sumStats.fun(countsProvKB)     # stats will be very different when comparing SM and KB
sumStats.fun(countsProvSM)
sumStats.fun(countsProvMPA)
sumStats.fun(countsProvMC)
sumStats.fun(countsFecesKB)    # especially if KB is not at species level!
sumStats.fun(countsFecesSM)
sumStats.fun(countsFecesMPA)
sumStats.fun(countsFecesMC)
sumStats.fun(countsSalivaKB)
sumStats.fun(countsSalivaSM)
sumStats.fun(countsSalivaMPA)
sumStats.fun(countsSalivaMC)

### We test for the normality of some continuous variables
contVars <- c("age", "BMI", "weight","storageTime","libSize","concDNA","numBins","contDNA","meanFP") # variables to test
dayVars <- metaProv$treatDay %>% na.omit %>% unique # subset data for sampling date
compVars <- metaProv$compart %>% na.omit %>% unique# subset data for sampling compart
for (k in contVars) {
  paste("...Data normality test for",k,":") %>% message
  for (j in dayVars) {
    for (i in compVars) {
      test <- metaProv %>%
        filter(treatDay == j & compart == i & group!= "LD") %>% # so we only test independent samples!
        dplyr::select(all_of(k)) %>% unlist %>% # make sure k is a numerical vector
        as.numeric %>% shapiro.test # and run the test!
      test$p.value %>% # we print the p-values for each
        format(scientific = F, digits = 2) %>% # readability
        paste(i,j,., sep = " ") %>% message
    }; remove(test)# All numerical variables are normally distributed.
  } # Use non-parametric tests with non-normally distributed variables!
}
  #++++ or normalise them ??(not coded yet)
#! libSize is non-normal for F start
#! concDNA is non-normal for S start and end
#! contDNA is non-normal for F
#! meanFP is non-normal for end

#######################···
#### Sanity Checks ####····
#######################···

# The following function performs a series of tests to make sure the
# data structure is coherent and prints a comment on your terminal.
sanity_fun <- function(counts,meta) {
  message("if not character(0), otherwise sample names do not match :")
    setdiff(colnames(counts),rownames(meta))    %>% print
  message("if not integer(0), number of taxa don't match between counts and metadata :")
    (nrow(meta) != ncol(counts)) %>% which      %>% print
  message("if not integer(0), sample names don't match or are missing in either table :")
    (rownames(meta[order(row.names(meta)),]) != colnames(counts[,order(colnames(counts))])) %>%
    which %>% print
  message("number of samples without any taxa count :")
    which(apply(counts,2,sum) == 0) %>% length %>% print
  message("number of taxa absent from all samples :")
    which(apply(counts,1,sum) == 0) %>% length %>% print
} # run the function on your data subsets using the following arguments :
sanity_fun(countsProvKB,metaProv)
sanity_fun(countsProvSM, metaProv)
sanity_fun(countsProvMPA, metaProv) # did you remove Provid-LD samples?
sanity_fun(countsProvMC, metaProv)
sanity_fun(countsSalivaKB, metaSaliva)
sanity_fun(countsSalivaSM, metaSaliva)
sanity_fun(countsSalivaMPA, metaSaliva)
sanity_fun(countsSalivaMC, metaSaliva)
sanity_fun(countsFecesKB, metaFeces)
sanity_fun(countsFecesSM, metaFeces)
sanity_fun(countsFecesMPA, metaFeces)
sanity_fun(countsFecesMC, metaFeces)
sanity_fun(countsMockKB, metaMock)
sanity_fun(countsMockSM, metaMock)
sanity_fun(countsMockMPA, metaMock)

#######################################···
#### Phyloseq Objects & Data Export ####····
#######################################···

### This loop looks complicated, but it simply allows us to use character strings
### such as "KB" or "Feces" to construct object names with the paste0 function.
### It is an attempt at automating multiple object creations when working with
### many subsets or analogous tables in a comparative study.

### MAKE SURE the defined strings are the sames as for object names !

### 1st level: sample subset designation
for (j in c("Mock","Prov","Feces","Saliva")) { # suffixes used for subsetting
  assign("meta",paste0("meta",j)) # metadata name created, e.g. metaFeces

  ### 2nd level: classifier (taxonomic or functional)
  ### Mock community is ignored in some datasets (ex. functional) so:
  mockT <- c("SM","KB","MPA") # table types for which you DID keep the mock
  mockF <- c("MC") # table types for which you did NOT
  if (j=="Mock") {classifier = mockT} else {classifier = c(mockT,mockF)}

  for (i in classifier) { # suffixes used for taxonomer used
    assign("ps",paste0("ps",j,i)) # ps object name
    assign("otu",paste0("counts",j,i)) # counts table name
      # assign() stores the name created by paste0() as a character value

    if(i=="MC") {assign("type","path")} else {assign("type","tax")}
      assign("tax",paste0(type,j,i))

    ### We create the phyloseq objects by using ps's value (created above)
    ### to name object and assign it the following:
    assign(ps,phyloseq(otu_table(get(otu), taxa_are_rows = T),
                      sample_data(get(meta)),
                      tax_table(get(tax)))) # get() reads a string as an object name
    ps %>% paste("phyloseq object created") %>% message # verbose for your sanity (:

    # EXPORT this object for use in other scripts
    ps %>% get %T>% print %>% # print ps object summary "outside" the pipe
      saveRDS(paste0("objects/",ps,".rds"))

    # ALSO export each table separately (the ones used to build the ps objects)
    for (k in c("counts",type)) {
      paste0(k,j,i) %>% get %>% saveRDS(paste0("objects/",k,j,i,".rds"))
      }
    # one metadata to rule them all :
  }; paste0("meta",j) %>% get %>% saveRDS(paste0("objects/","meta",j,".rds"))
    # we remove useless objects :
}; remove(otu,meta,tax,i,j,ps,classifier)

# Some extra tables we want to save:
saveRDS(partDataProv, "objects/partDataProv.rds")
saveRDS(fluPro, "objects/fluProScores.rds")

################################################################################
### DONE! :-) ##################################################################
################################################################################
# remove(rawKBcounts,rawSMcounts,rawMPAcounts,tmp,rawSM,package.check,contVars,compVars,dayVars,k,num_vars,factor_vars,samplesFeces,samplesSaliva,taxCodes,taxNames,taxoSM,packages)

# inspired by https://vaulot.github.io/tutorials/Phyloseq_tutorial.html ######