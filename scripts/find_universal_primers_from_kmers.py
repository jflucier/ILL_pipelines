import pandas as pd
import sys
import numpy as np
import argparse
import os

# NOTE: TARGET_ASSEMBLIES is now dynamically determined from the input file
# Global cache for FASTA sequences: {assembly.contig_key: sequence_string}
FASTA_CACHE = {}


# --- Helper Functions for Sequence Loading ---

def load_fasta_sequence(assembly, contig, fasta_dir):
    """
    Loads a sequence from a FASTA file into the global cache.
    Handles wrapped (multi-line) FASTA format by concatenating all lines after the header.
    File name convention: <assembly>.<contig>.fasta
    """
    key = f"{assembly}.{contig}"
    if key in FASTA_CACHE:
        return FASTA_CACHE[key]

    # Construct the file path using the assembly and contig names
    file_path = os.path.join(fasta_dir, f"{assembly}.{contig}.fasta")

    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()

            if not lines:
                print(f"Warning: FASTA file is empty: {file_path}")
                FASTA_CACHE[key] = None
                return None

            # Skip the header line (index 0) and read all subsequent lines
            sequence_lines = lines[1:]

            # Concatenate all sequence lines, strip whitespace (newlines), and convert to uppercase
            sequence = "".join(line.strip() for line in sequence_lines).upper()

            if not sequence:
                print(f"Warning: FASTA file sequence is empty after parsing: {file_path}")
                FASTA_CACHE[key] = None
                return None

            FASTA_CACHE[key] = sequence
            return sequence

    except FileNotFoundError:
        print(f"Error: FASTA file not found for {key} at {file_path}. Cannot extract sequence.")
        FASTA_CACHE[key] = None
        return None
    except Exception as e:
        print(f"Error reading FASTA file {file_path}: {e}")
        FASTA_CACHE[key] = None
        return None


def get_all_assemblies_from_file(input_file):
    """
    Reads the input TSV file and returns a set of all unique assembly IDs
    found in the 'assembly' column.
    """
    print(f"Reading {input_file} to dynamically determine target assemblies...")
    try:
        # Load only the 'assembly' column
        df = pd.read_csv(input_file, sep='\t', usecols=['assembly'])
        unique_assemblies = set(df['assembly'].unique())
        print(f"Dynamically identified {len(unique_assemblies)} unique assemblies to target.")
        return unique_assemblies
    except Exception as e:
        print(f"Error reading file to determine target assemblies: {e}")
        return set()


def generate_homology_map_from_file(input_file, target_assemblies):
    """
    Computes a dictionary mapping assembly IDs to a list of all unique contig IDs
    present in that assembly within the input file, restricted to the target_assemblies.
    This dynamically creates the TARGET_HOMOLOGY_MAP.
    """
    print(f"Generating homology map from {input_file}...")
    try:
        # Load only necessary columns for map generation
        df = pd.read_csv(input_file, sep='\t', usecols=['assembly', 'contig'])
    except Exception as e:
        print(f"Error loading file for map generation: {e}")
        return {}

    # Filter to only include the assemblies we care about (which is all of them now)
    df_filtered = df[df['assembly'].isin(target_assemblies)].copy()

    # Group by assembly and collect all unique contigs into a list
    contig_map = df_filtered.groupby('assembly')['contig'].unique().apply(list).to_dict()

    print(f"Map generated for {len(contig_map)} assemblies.")
    return contig_map


# --- Main Analysis Function ---

def find_universal_primers(input_file, output_file, min_product_size, max_product_size, fasta_dir, target_homology_map):
    """
    Analyzes the k-mer position data to find universal primer pairs and extracts the amplicon sequence.
    Refactored to use DataFrame merges for efficiency, following the logic:
    1. Find all valid amplicons (Fwd(+) < Rev(-) on same contig, within size constraints)
    2. Filter these amplicons to find pairs that are universal across ALL assemblies.
    """
    print(f"Loading data from {input_file}...")
    try:
        df = pd.read_csv(input_file, sep='\t')
    except Exception as e:
        print(f"Error loading file: {e}")
        return

    # 1. Filter data to only include the target assemblies/contigs for efficiency
    target_assemblies = set(target_homology_map.keys())
    df_filtered = df[df['assembly'].isin(target_assemblies)].copy()

    # 2. Separate Fwd (+) and Rev (-) k-mers
    fwd_kmers_df = df_filtered[df_filtered['strand'] == '+'].rename(
        columns={'seq': 'Fwd_Kmer', 'position': 'Fwd_Start_Pos'}
    ).drop(columns=['strand']).copy()

    rev_kmers_df = df_filtered[df_filtered['strand'] == '-'].rename(
        columns={'seq': 'Rev_Kmer', 'position': 'Rev_Start_Pos'}
    ).drop(columns=['strand']).copy()

    # Determine k-mer length (assume all kmers are the same length, use the first one)
    kmer_len = len(fwd_kmers_df['Fwd_Kmer'].iloc[0]) if not fwd_kmers_df.empty else 0
    if kmer_len == 0:
        print("Error: No forward k-mers found or k-mer length is zero. Exiting analysis.")
        return None

    print(f"k-mer length determined to be {kmer_len}.")
    print("Finding all valid Fwd(+) < Rev(-) pairings on the same contig...")

    # 3. Merge Fwd and Rev dataframes on (assembly, contig) to find all possible pairs on the same segment.
    # This efficiently creates the list of k-mer pairs on different strands on the same contig (User Step 1).
    all_pairs_df = pd.merge(
        fwd_kmers_df,
        rev_kmers_df,
        on=['assembly', 'contig'],
        how='inner'
    )

    # Filter out cases where the kmer is paired with itself
    all_pairs_df = all_pairs_df[all_pairs_df['Fwd_Kmer'] != all_pairs_df['Rev_Kmer']]

    # 4. Apply PCR conditions (Order and Size)

    # Condition A: Correct Order (Fwd start must be before Rev start on the forward strand)
    valid_order_df = all_pairs_df[all_pairs_df['Fwd_Start_Pos'] < all_pairs_df['Rev_Start_Pos']].copy()

    # Calculate product size
    valid_order_df['Calculated_Size'] = valid_order_df['Rev_Start_Pos'] - valid_order_df['Fwd_Start_Pos'] + kmer_len

    # Condition B: Filter by MINIMUM and MAXIMUM length
    valid_amplicons_df = valid_order_df[
        (valid_order_df['Calculated_Size'] >= min_product_size) &
        (valid_order_df['Calculated_Size'] <= max_product_size)
        ].reset_index(drop=True)

    if valid_amplicons_df.empty:
        print("\n--- Analysis Complete ---")
        print(
            f"No valid k-mer pairings found meeting the size and order criteria ({min_product_size}-{max_product_size} bp).")
        return None

    print(f"Found {len(valid_amplicons_df)} potential valid amplicons across all assemblies.")

    # 5. Check Universality: Filter for pairs that are present in ALL target assemblies (User Step 2).

    # Group by the primer pair and count how many unique assemblies they hit
    pair_assembly_counts = valid_amplicons_df.groupby(['Fwd_Kmer', 'Rev_Kmer'])['assembly'].nunique().reset_index(
        name='Assembly_Count')

    # Identify the universal pairs (count must equal the total number of target assemblies)
    universal_pair_sequences = pair_assembly_counts[pair_assembly_counts['Assembly_Count'] == len(target_assemblies)]

    if universal_pair_sequences.empty:
        print("\n--- Analysis Complete ---")
        print(
            f"No universal primer pairs found that consistently maintain the Fwd(+) < Rev(-) position AND yield a product size between {min_product_size} and {max_product_size} bp in all {len(target_homology_map)} target strains.")
        return None

    # Merge the universal pairs list back into the full list of valid amplicons to get the final results
    universal_results_df = pd.merge(
        valid_amplicons_df,
        universal_pair_sequences[['Fwd_Kmer', 'Rev_Kmer']],
        on=['Fwd_Kmer', 'Rev_Kmer'],
        how='inner'
    ).sort_values(by=['Fwd_Kmer', 'Rev_Kmer', 'assembly']).reset_index(drop=True)

    # 6. Calculate consistency metrics
    metrics = universal_results_df.groupby(['Fwd_Kmer', 'Rev_Kmer'])['Calculated_Size'].agg(
        Product_Size_Avg=lambda x: int(x.mean()),
        Product_Size_Min=lambda x: int(x.min()),
        Product_Size_Max=lambda x: int(x.max())
    ).reset_index()

    # Merge the metrics into the results DataFrame
    universal_results_df = universal_results_df.merge(metrics, on=['Fwd_Kmer', 'Rev_Kmer'])

    print(f"Found {len(universal_pair_sequences)} universal primer pairs.")
    print("Extracting amplicon sequences for universal pairs...")

    # 7. Extract Amplicon Sequence (Apply this function row-wise)
    def extract_amplicon(row, fasta_dir):
        """Helper function to load sequence and extract amplicon."""
        sequence = load_fasta_sequence(row['assembly'], row['contig'], fasta_dir)

        amplicon_sequence = ""
        if sequence:
            # Fwd_pos is 1-based start. Python slice start is Fwd_Start_Pos - 1.
            # Amplicon ends at Rev_Start_Pos + kmer_len - 1. Python slice end is exclusive.
            start_idx = row['Fwd_Start_Pos'] - 1
            end_idx = row['Rev_Start_Pos'] + kmer_len - 1

            if end_idx <= len(sequence):
                amplicon_sequence = sequence[start_idx:end_idx]
            else:
                amplicon_sequence = f"ERROR_INDEX_OUT_OF_BOUNDS (Contig Len: {len(sequence)}, End Index: {end_idx})"
        else:
            amplicon_sequence = "FASTA_LOAD_FAILED"

        return amplicon_sequence

    # Apply the extraction function
    # NOTE: The original map filtering on homologous contigs is implicitly handled here because the
    # initial dataframe df_filtered contains only k-mer hits (assembly, contig) that were present
    # in the input file, which is used to generate the TARGET_HOMOLOGY_MAP.
    universal_results_df['Amplicon_Sequence'] = universal_results_df.apply(
        extract_amplicon, axis=1, fasta_dir=fasta_dir
    )

    # 8. Final Output
    final_columns = [
        'Fwd_Kmer', 'Rev_Kmer', 'Product_Size_Avg', 'Product_Size_Min', 'Product_Size_Max',
        'Amplicon_Sequence',
        'Assembly', 'Contig', 'Fwd_Start_Pos', 'Rev_Start_Pos', 'Calculated_Size'
    ]

    # Save final results
    universal_results_df.to_csv(output_file, sep='\t', index=False, columns=final_columns)

    print(f"\n--- Analysis Complete ---")
    print(
        f"Found universal primer pair groups that yield products between {min_product_size} and {max_product_size} bp.")
    print(f"Details saved to {output_file}")

    # Print a summary table to the console
    summary_df = universal_results_df[
        ['Fwd_Kmer', 'Rev_Kmer', 'Product_Size_Avg', 'Product_Size_Min',
         'Product_Size_Max']].drop_duplicates().reset_index(drop=True)
    print(
        f"\nSummary of Universal Primer Pairs (All products between {min_product_size} and {max_product_size} bp):")

    # Display the summary in markdown for the user
    print(summary_df.to_markdown(index=False))

    return universal_results_df


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

    # 1. Dynamically get all target assemblies from the input file
    TARGET_ASSEMBLIES = get_all_assemblies_from_file(args.input_file)

    if not TARGET_ASSEMBLIES:
        print("Error: Could not determine target assemblies from input file. Exiting.")
        sys.exit(1)

    # 2. Dynamically generate TARGET_HOMOLOGY_MAP based on the newly defined TARGET_ASSEMBLIES
    TARGET_HOMOLOGY_MAP = generate_homology_map_from_file(args.input_file, TARGET_ASSEMBLIES)

    # --- START: Added printing for debugging ---
    print("\n--- TARGET_HOMOLOGY_MAP Content (Assembly ID -> Contigs) ---")
    # Loop through the dictionary to print each item clearly
    for assembly, contigs in TARGET_HOMOLOGY_MAP.items():
        print(f"  {assembly}: {', '.join(contigs)}")
    print("----------------------------------------------------------\n")
    # --- END: Added printing for debugging ---

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
