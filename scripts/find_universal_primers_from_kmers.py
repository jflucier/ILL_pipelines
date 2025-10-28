import pandas as pd
import sys
import numpy as np
import argparse
import os

# Define the target strains. These are the assemblies we care about.
TARGET_ASSEMBLIES_LIST = [
    'GCF_001423335.1_Leaf289_genomic',
    'GCF_001423465.1_Leaf129_genomic',
    'GCF_001423565.1_Leaf145_genomic'
]
TARGET_ASSEMBLIES = set(TARGET_ASSEMBLIES_LIST)

# Global cache for FASTA sequences: {assembly.contig_key: sequence_string}
FASTA_CACHE = {}


# --- Helper Functions for Sequence Loading ---

def load_fasta_sequence(assembly, contig, fasta_dir):
    """
    Loads a sequence from a FASTA file into the global cache.
    Assumes simple FASTA format (one header, one sequence line, no wrapping).
    File name convention: <assembly>.<contig>.fasta
    """
    key = f"{assembly}.{contig}"
    if key in FASTA_CACHE:
        return FASTA_CACHE[key]

    # Construct the file path using the assembly and contig names
    file_path = os.path.join(fasta_dir, f"{assembly}.{contig}.fasta")

    try:
        with open(file_path, 'r') as f:
            # Skip the header line (first line)
            f.readline()
            # Read the sequence (second line), remove whitespace, and convert to uppercase
            # Assumes the sequence is on a single line after the header
            sequence = f.readline().strip().upper()

            if not sequence:
                print(f"Warning: FASTA file appears empty or malformed: {file_path}")
                FASTA_CACHE[key] = None
                return None

            FASTA_CACHE[key] = sequence
            return sequence

    except FileNotFoundError:
        # Cannot use sys.exit(1) here as it's called inside the main loop
        print(f"Error: FASTA file not found for {key} at {file_path}. Cannot extract sequence.")
        FASTA_CACHE[key] = None
        return None
    except Exception as e:
        print(f"Error reading FASTA file {file_path}: {e}")
        FASTA_CACHE[key] = None
        return None


def generate_homology_map_from_file(input_file, target_assemblies):
    """
    Computes a dictionary mapping assembly IDs to a list of all unique contig IDs
    present in that assembly within the input file, restricted to the target_assemblies.
    This dynamically creates the TARGET_HOMOLOGY_MAP.
    """
    print(f"Dynamically generating homology map from {input_file}...")
    try:
        # Load only necessary columns for map generation
        df = pd.read_csv(input_file, sep='\t', usecols=['assembly', 'contig'])
    except Exception as e:
        print(f"Error loading file for map generation: {e}")
        return {}

    # Filter to only include the assemblies we care about
    df_filtered = df[df['assembly'].isin(target_assemblies)].copy()

    # Group by assembly and collect all unique contigs into a list
    contig_map = df_filtered.groupby('assembly')['contig'].unique().apply(list).to_dict()

    # Check if all target assemblies were found
    if len(contig_map) < len(target_assemblies):
        missing = target_assemblies - set(contig_map.keys())
        print(f"Warning: The following target assemblies were not found in the input file: {', '.join(missing)}")

    print(f"Map generated for {len(contig_map)} assemblies.")
    return contig_map


# --- Main Analysis Function ---

def find_universal_primers(input_file, output_file, min_product_size, max_product_size, fasta_dir, target_homology_map):
    """
    Analyzes the k-mer position data to find universal primer pairs and extracts the amplicon sequence.
    """
    print(f"Loading data from {input_file}...")
    try:
        df = pd.read_csv(input_file, sep='\t')
    except Exception as e:
        print(f"Error loading file: {e}")
        return

    # Filter data to only include the target assemblies/contigs for efficiency
    target_assemblies = set(target_homology_map.keys())
    df_filtered = df[df['assembly'].isin(target_assemblies)].copy()

    # Store results (list of lists of match dictionaries)
    universal_pairs_groups = []

    # Get all unique k-mers found in this dataset
    unique_kmers = df_filtered['seq'].unique()

    print(f"Found {len(unique_kmers)} unique k-mers to check.")
    print(f"Filtering for product size between {min_product_size} and {max_product_size} bp.")

    # Iterate through all possible pairs of k-mers (Kmer_F, Kmer_R)
    for i in range(len(unique_kmers)):
        kmer_fwd_seq = unique_kmers[i]

        # Kmer_Fwd will be the candidate for the Forward primer (+)
        fwd_df = df_filtered[(df_filtered['seq'] == kmer_fwd_seq) & (df_filtered['strand'] == '+')]

        # Optimization: Skip if Fwd is not found on '+' strand in all target assemblies
        if fwd_df.empty or len(fwd_df['assembly'].unique()) < len(target_assemblies):
            continue

        for j in range(len(unique_kmers)):
            if i == j:  # Cannot be the same k-mer
                continue

            kmer_rev_seq = unique_kmers[j]

            # Kmer_Rev will be the candidate for the Reverse primer (-)
            rev_df = df_filtered[(df_filtered['seq'] == kmer_rev_seq) & (df_filtered['strand'] == '-')]

            # Optimization: Skip if Rev is not found on '-' strand in all target assemblies
            if rev_df.empty or len(rev_df['assembly'].unique()) < len(target_assemblies):
                continue

            is_universal_pair = True
            all_valid_universal_matches = []  # List to store ALL valid match dicts (one for each valid product)

            # Check all three strains for the conditions
            for assembly, homologous_contigs in target_homology_map.items():

                # Get the relevant data points for this specific assembly/contig group
                # FIX: Ensure boolean masks are generated only from the DataFrame being filtered (fwd_df/rev_df)
                fwd_match = fwd_df[(fwd_df['assembly'] == assembly) & (fwd_df['contig'].isin(homologous_contigs))]
                rev_match = rev_df[(rev_df['assembly'] == assembly) & (rev_df['contig'].isin(homologous_contigs))]

                # Condition 1 & 2: Kmer F must be + and Kmer R must be - in this assembly/contig
                if fwd_match.empty or rev_match.empty:
                    is_universal_pair = False
                    break  # Kmers are not present in the required orientation in this strain

                # --- Find ALL valid matches (Fwd < Rev & Product Size between MIN and MAX) ---
                all_valid_matches_for_assembly = []
                kmer_len = len(kmer_fwd_seq)  # k-mer length correction

                # Iterate through all possible forward matches
                for _, fwd_row in fwd_match.iterrows():
                    fwd_pos = fwd_row['position']
                    fwd_contig_id = fwd_row['contig']

                    # Iterate through all possible reverse matches
                    for _, rev_row in rev_match.iterrows():
                        rev_pos = rev_row['position']
                        rev_contig_id = rev_row['contig']

                        # Only allow pairing if they are on the same specific contig
                        if fwd_contig_id != rev_contig_id:
                            continue

                        # Condition A: Correct Order (Fwd start must be before Rev start on the forward strand)
                        if fwd_pos < rev_pos:
                            product_size = rev_pos - fwd_pos + kmer_len

                            # Condition B: Filter by MINIMUM and MAXIMUM length
                            if min_product_size <= product_size <= max_product_size:

                                # 1. Load the sequence
                                sequence = load_fasta_sequence(assembly, fwd_contig_id, fasta_dir)

                                amplicon_sequence = ""
                                if sequence:
                                    # 2. Extract the amplicon sequence using 0-based indexing for Python slicing
                                    # Fwd_pos is 1-based start. Python slice start is fwd_pos - 1.
                                    # Amplicon ends at Rev_pos + kmer_len - 1. Python slice end is exclusive.
                                    start_idx = fwd_pos - 1
                                    end_idx = rev_pos + kmer_len - 1

                                    # Ensure indices are valid before slicing
                                    if end_idx <= len(sequence):
                                        amplicon_sequence = sequence[start_idx:end_idx]
                                    else:
                                        amplicon_sequence = "ERROR_SEQUENCE_INDEX_OUT_OF_BOUNDS"
                                else:
                                    amplicon_sequence = "FASTA_LOAD_FAILED"

                                # Found a valid match!
                                match_dict = {
                                    'Fwd_Kmer': kmer_fwd_seq,
                                    'Rev_Kmer': kmer_rev_seq,
                                    'Assembly': assembly,
                                    'Contig': fwd_contig_id,
                                    'Fwd_Start_Pos': fwd_pos,
                                    'Rev_Start_Pos': rev_pos,
                                    'Calculated_Size': product_size,
                                    'Amplicon_Sequence': amplicon_sequence
                                }
                                all_valid_matches_for_assembly.append(match_dict)

                if not all_valid_matches_for_assembly:
                    is_universal_pair = False
                    break  # No match (of length min-max) found for this specific assembly

                all_valid_universal_matches.extend(all_valid_matches_for_assembly)

            if is_universal_pair and all_valid_universal_matches:
                # Store all matches found across all strains for this kmer pair
                universal_pairs_groups.append(all_valid_universal_matches)

    # Convert results to a presentable DataFrame
    if universal_pairs_groups:
        # Flatten the list of lists into a single list of dictionaries
        flat_results = [match for sublist in universal_pairs_groups for match in sublist]

        # Convert to DataFrame
        results_df = pd.DataFrame(flat_results)

        # Calculate consistency metrics.
        metrics = results_df.groupby(['Fwd_Kmer', 'Rev_Kmer'])['Calculated_Size'].agg(
            # Calculate Avg Size (convert to int)
            Product_Size_Avg=lambda x: int(x.mean()),
            # Calculate Min Size (convert to int)
            Product_Size_Min=lambda x: int(x.min()),
            # Calculate Max Size (convert to int)
            Product_Size_Max=lambda x: int(x.max())
        ).reset_index()

        # Merge the metrics back into the main results DataFrame
        results_df = results_df.merge(metrics, on=['Fwd_Kmer', 'Rev_Kmer'])

        # Define final columns for TSV output
        final_columns = [
            'Fwd_Kmer', 'Rev_Kmer', 'Product_Size_Avg', 'Product_Size_Min', 'Product_Size_Max',
            'Amplicon_Sequence',
            'Assembly', 'Contig', 'Fwd_Start_Pos', 'Rev_Start_Pos', 'Calculated_Size'
        ]

        # Use the new output file name
        results_df.to_csv(output_file, sep='\t', index=False, columns=final_columns)

        print(f"\n--- Analysis Complete ---")
        print(
            f"Found universal primer pair groups that yield products between {min_product_size} and {max_product_size} bp.")
        print(f"Details saved to {output_file}")

        # Print a summary table to the console
        summary_df = results_df[
            ['Fwd_Kmer', 'Rev_Kmer', 'Product_Size_Avg', 'Product_Size_Min',
             'Product_Size_Max']].drop_duplicates().reset_index(drop=True)
        print(
            f"\nSummary of Universal Primer Pairs (All products between {min_product_size} and {max_product_size} bp):")

        # Display the summary in markdown for the user
        print(summary_df.to_markdown(index=False))

        return results_df
    else:
        print("\n--- Analysis Complete ---")
        print(
            f"No universal primer pairs found that consistently maintain the Fwd(+) < Rev(-) position AND yield a product size between {min_product_size} and {max_product_size} bp in all three strains on the homologous contigs.")
        return None


def main():
    """
    Handles command-line arguments and runs the primer analysis.
    """
    # Create the parser
    parser = argparse.ArgumentParser(
        description="Finds universal primer pairs based on k-mer positions across multiple assemblies."
    )

    # Add arguments with default values
    parser.add_argument(
        '--input_file',
        type=str,
        default='multiassembly_kmers_positions.tsv',
        help='Input TSV file containing k-mer positions (default: multiassembly_kmers_positions.tsv)'
    )
    parser.add_argument(
        '--output_file',
        type=str,
        default='universal_primer_pairs_short.tsv',
        help='Output TSV file for universal primer pairs (default: universal_primer_pairs_short.tsv)'
    )
    parser.add_argument(
        '--max_product_size',
        type=int,
        default=7000,
        help='Maximum allowed PCR product size in base pairs (default: 7000)'
    )
    parser.add_argument(
        '--min_product_size',
        type=int,
        default=150,
        help='Minimum allowed PCR product size in base pairs (default: 150)'
    )
    parser.add_argument(
        '--fasta_dir',
        type=str,
        default='./assembly/',
        help='Directory containing the FASTA files named <assembly>.<contig>.fasta. (default: ./assembly/)'
    )

    # Parse arguments
    args = parser.parse_args()

    # Check if the input file exists
    if not pd.io.common.file_exists(args.input_file):
        print(f"Error: Input file '{args.input_file}' not found. Please ensure it is uploaded.")
        sys.exit(1)

    # Dynamically generate TARGET_HOMOLOGY_MAP
    TARGET_HOMOLOGY_MAP = generate_homology_map_from_file(args.input_file, TARGET_ASSEMBLIES)

    # Check if the generated map is usable
    if not TARGET_HOMOLOGY_MAP:
        print("Error: Could not generate TARGET_HOMOLOGY_MAP. Exiting.")
        sys.exit(1)

    # Run the main analysis function
    find_universal_primers(
        args.input_file,
        args.output_file,
        args.min_product_size,
        args.max_product_size,
        args.fasta_dir,  # Pass the FASTA directory
        TARGET_HOMOLOGY_MAP
    )


if __name__ == "__main__":
    main()
