import re
import os
import argparse
import sys


def clean_sequence_name(name):
    """Cleans the sequence name for use in file names or FASTA headers."""
    # Removes characters that are problematic in FASTA headers or filenames
    return re.sub(r'[|:]', '_', name)


def clean_consensus_for_filename(consensus):
    """Cleans the motif consensus for safe use in filenames."""
    # Replaces problematic regex/IUPAC characters with underscores
    return re.sub(r'[\[\]\|\.\*\+\?]', '_', consensus)


def parse_meme_output_to_tsv_and_fasta(input_file, output_directory):
    """
    Parses a MEME text output file to generate separate TSV and FASTA files for each motif.
    """
    if not os.path.exists(input_file):
        print(f"Error: The input file '{input_file}' was not found.")
        sys.exit(1)

    # 1. Pattern for capturing motif blocks, including the consensus and label
    motif_block_pattern = re.compile(
        r'^(-{70,})\s*\n'
        r'^-{70,}\s*\n'
        # Capture 1: motif_consensus (IUPAC sequence)
        # Capture 2: motif_label (e.g., MEME-1)
        r'\s*Motif\s+(?P<motif_consensus>\S+)\s+(?P<motif_label>MEME-\d+)\s+sites sorted by position p-value\s*\n'
        r'^(-{70,})\s*\n'
        r'(?P<sites_data>.*?)\n'
        r'^-{70,}\s*$',
        re.DOTALL | re.MULTILINE
    )

    # 2. Pattern for parsing individual site lines (robust to flanking sequences)
    site_line_pattern = re.compile(
        r'^(?P<seq_name>\S+)\s+'  # 1. Sequence name
        r'(?P<start>\d+)\s+'  # 2. Start position
        r'(?P<pvalue>[0-9\.eE\-]+)\s+'  # 3. P-value
        r'\S+\s+'  # 4. Flanking Sequence 1 (Ignored)
        r'(?P<site>\S+)\s+'  # 5. Site Sequence (Captured)
        r'\S+\s*$'  # 6. Flanking Sequence 2 (Ignored until end of line)
    )

    # Read the entire file content
    try:
        with open(input_file, 'r') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading input file: {e}")
        sys.exit(1)

    os.makedirs(output_directory, exist_ok=True)
    total_motifs_processed = 0

    # Find all motif blocks
    for match in motif_block_pattern.finditer(content):
        motif_consensus = match.group('motif_consensus')
        motif_label = match.group('motif_label')
        sites_data = match.group('sites_data')

        safe_consensus = clean_consensus_for_filename(motif_consensus)

        # Define both output filenames
        tsv_output_filename = os.path.join(output_directory, f"motif_{safe_consensus}_{motif_label}.tsv")
        fasta_output_filename = os.path.join(output_directory, f"motif_{safe_consensus}_{motif_label}.fasta")
        sites_found_count = 0

        try:
            # Open both files for writing within the motif loop
            with open(tsv_output_filename, 'w') as tsv_f, \
                    open(fasta_output_filename, 'w') as fasta_f:

                # Write TSV Header
                tsv_f.write("sequence name\tstart\tpvalue\tsite\n")

                # Process each line of site data
                for line in sites_data.strip().split('\n'):
                    if not line.strip():
                        continue

                    line_match = site_line_pattern.match(line.strip())

                    if line_match:
                        seq_name = line_match.group('seq_name')
                        start = line_match.group('start')
                        pvalue = line_match.group('pvalue')
                        site = line_match.group('site')

                        # 1. Write to TSV
                        tsv_f.write(f"{seq_name}\t{start}\t{pvalue}\t{site}\n")

                        # 2. Write to FASTA (Header: "sequence_name"_"pos")
                        fasta_header = f">{clean_sequence_name(seq_name)}_{start}"
                        fasta_f.write(fasta_header + "\n")
                        fasta_f.write(site + "\n")

                        sites_found_count += 1

            if sites_found_count > 0:
                total_motifs_processed += 1
                print(f"Successfully generated: {tsv_output_filename} (TSV)")
                print(f"Successfully generated: {fasta_output_filename} (FASTA)")
            else:
                # Delete files if only headers were written (no sites found)
                os.remove(tsv_output_filename)
                os.remove(fasta_output_filename)
                # print(f"Deleted empty files for motif: {motif_label}")

        except Exception as e:
            print(f"Error processing motif {motif_label}: {e}")

    if total_motifs_processed == 0:
        print("\nNo motifs or valid site data sections were found in the file matching the expected MEME format.")
    else:
        print(f"\n--- Processing complete. Total motifs processed: {total_motifs_processed} ---")


def main():
    parser = argparse.ArgumentParser(
        description="Parse a MEME text output file and generate separate TSV and FASTA files for each motif's sites."
    )
    parser.add_argument(
        'meme_file',
        type=str,
        help='The path to the input MEME text output file (e.g., meme.txt).'
    )
    parser.add_argument(
        'output_dir',
        type=str,
        help='The path to the output directory where TSV and FASTA files will be saved.'
    )

    args = parser.parse_args()

    parse_meme_output_to_tsv_and_fasta(args.meme_file, args.output_dir)


if __name__ == '__main__':
    main()