import pandas as pd
from Bio import SeqIO
from Bio.Seq import Seq
import os
import argparse
import sys

# Cache for sequences to avoid re-reading files
SEQUENCE_CACHE = {}


def load_fasta_sequence(fasta_base_dir, pair_clean):
    """
    Loads the sequence for a given contig from its FASTA file, using a global cache.
    """
    cache_key = f"{pair_clean}"
    if cache_key in SEQUENCE_CACHE:
        return SEQUENCE_CACHE[cache_key]

    # Construct the full file path
    # Assuming file structure: fasta_base_dir/ASSEMBLY_NAME/CONTIG_NAME.fasta
    fasta_filename = f"{pair_clean}.fasta"
    fasta_path = os.path.join(fasta_base_dir, fasta_filename)

    if not os.path.exists(fasta_path):
        # Fallback in case the .fasta extension is missing in the file system
        print(f"Warning: FASTA file not found at {fasta_path}. Skipping.")
        return None

    try:
        # Read the sequence record
        record = SeqIO.read(fasta_path, "fasta")
        sequence = str(record.seq).upper()

        # Store in cache
        SEQUENCE_CACHE[cache_key] = sequence
        return sequence
    except Exception as e:
        print(f"Error reading {fasta_path}: {e}. Skipping.")
        return None


def find_kmer_positions(tsv_file, fasta_base_dir):
    """
    Reads the TSV, finds k-mer positions, and writes the output in a row-per-match format.
    """

    # Define the output file based on the input TSV name
    output_file = tsv_file.replace('.tsv', '_positions.tsv')
    if tsv_file == output_file:
        output_file = "kmer_positions_results.tsv"

    print(f"Reading input k-mer file: {tsv_file}")
    print(f"Using FASTA base directory: {fasta_base_dir}")

    # Read the TSV file (assuming tab separation)
    try:
        df = pd.read_csv(tsv_file, sep='\t', engine='python')
        # Clean up column names in case of whitespace issues from the input file generation
        df.columns = df.columns.str.strip()
    except Exception as e:
        print(f"Error reading TSV: {e}. Check file path and separator.")
        sys.exit(1)

    # Check if the required columns exist
    if not all(col in df.columns for col in ['seq', 'contigs']):
        print("Error: Input file must contain 'seq' and 'contigs' columns.")
        sys.exit(1)

    # List to store the final, flattened results (one dictionary per k-mer match)
    results = []

    print(f"Processing {len(df)} k-mer entries...")
    for index, row in df.iterrows():
        kmer_seq = row['seq'].strip().upper()
        contigs_list_str = row['contigs']

        # Calculate the reverse complement sequence
        try:
            rev_comp_seq = str(Seq(kmer_seq).reverse_complement()).upper()
        except Exception as e:
            print(f"Error calculating reverse complement for {kmer_seq}: {e}. Skipping k-mer.")
            continue

        # Split the comma-separated list of assembly:contig_id pairs
        contig_pairs = contigs_list_str.split(',')

        for pair in contig_pairs:
            try:
                # The user's data indicates the format is 'assembly.contig_id',
                # where the assembly name ends in '_genomic' and the separator is the dot immediately following it.
                pair_clean = pair.strip()

                # Use a known marker to reliably split the assembly from the contig ID
                sep_marker = '_genomic.'
                marker_index = pair_clean.find(sep_marker)

                if marker_index != -1:
                    # Assembly Name is everything up to the character before the separator dot
                    assembly_name = pair_clean[:marker_index + len('_genomic')]
                    # Contig ID is everything after the separator dot
                    contig_id = pair_clean[marker_index + len(sep_marker):]
                else:
                    # If the standard pattern is not found, we cannot reliably split it.
                    # This handles cases where the original SQL failed to concatenate with ':'
                    raise ValueError("Cannot reliably split pair into assembly and contig using '_genomic.' as marker.")

                # Clean and strip any whitespace
                assembly_name = assembly_name.strip()
                file_base_name = contig_id.strip()  # This is the desired 'contig' ID

                sequence = load_fasta_sequence(fasta_base_dir, pair_clean)

                if sequence:
                    # Search for both forward and reverse complement sequences
                    search_patterns = {
                        kmer_seq: '+',  # Search 1: Forward Strand
                        rev_comp_seq: '-'  # Search 2: Reverse Complement Strand
                    }

                    for pattern, strand in search_patterns.items():
                        position = 0
                        while True:
                            # Find the pattern starting search from the last found position + 1
                            position = sequence.find(pattern, position)

                            if position != -1:
                                # Append a new record for this specific match
                                # Note: 'seq' is always the original input kmer, not the matched pattern
                                results.append({
                                    'seq': kmer_seq,
                                    'assembly': assembly_name,
                                    'contig': file_base_name,
                                    'position': position,
                                    'strand': strand  # ADDED: The strand that matched the pattern
                                })
                                position += 1  # Advance search by one base
                            else:
                                break  # No more occurrences found

            except ValueError as ve:
                print(f"Error: Could not parse pair '{pair}'. Reason: {ve}. Skipping.")
                continue
            except Exception as e:
                print(f"Error processing k-mer {kmer_seq}, pair {pair}: {e}. Skipping pair.")
                continue

    # Write the final results
    results_df = pd.DataFrame(results)

    # Write only the desired columns in the specified order, including 'strand'
    final_columns = ['seq', 'assembly', 'contig', 'position', 'strand']
    results_df.to_csv(output_file, sep='\t', index=False, columns=final_columns)

    print(f"\nProcessing complete. Results saved to {output_file}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Finds the start position of k-mers within specific contig FASTA files and outputs results in a flattened, row-per-match format (seq\\tassembly\\tcontig\\tposition)."
    )
    parser.add_argument(
        'tsv_file',
        help="Path to the TSV file containing k-mers (e.g., multiassembly_kmers.tsv)."
    )
    parser.add_argument(
        'fasta_base_dir',
        help="Base directory containing the FASTA files (e.g., assembly_kmers21/assembly)."
    )

    args = parser.parse_args()

    # Run the main function with the command-line arguments
    find_kmer_positions(args.tsv_file, args.fasta_base_dir)
