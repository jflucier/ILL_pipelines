import re
import os
import argparse
from glob import glob
import csv

# Define the IUPAC degeneracy mapping for use in regex
IUPAC_MAPPING = {
    'R': '[AG]',  # Purine
    'Y': '[CT]',  # Pyrimidine
    'S': '[GC]',
    'W': '[AT]',
    'K': '[GT]',
    'M': '[AC]',
    'B': '[CGT]',  # Not A
    'D': '[AGT]',  # Not C
    'H': '[ACT]',  # Not G
    'V': '[ACG]',  # Not T
    'N': '[ACGT]',  # Any base
}

# Mapping for generating the reverse complement of standard bases (A, C, G, T)
COMPLEMENT_MAPPING = {
    'A': 'T', 'T': 'A',
    'C': 'G', 'G': 'C',
    'N': 'N',  # Handle 'N' if present in the sequence
}


def iupac_to_regex(degenerate_seq):
    """Converts a degenerate IUPAC DNA sequence into a standard regex pattern."""
    regex_pattern = ""
    for base in degenerate_seq.upper():
        # Check if the base is a degeneracy code, otherwise treat it as a literal base
        regex_pattern += IUPAC_MAPPING.get(base, base)
    return regex_pattern


def reverse_complement(seq):
    """Calculates the reverse complement of a DNA sequence."""
    seq = seq.upper()
    complement_list = [COMPLEMENT_MAPPING.get(base, base) for base in seq]
    # Reverse the complemented list and join
    return "".join(complement_list[::-1])


def read_fasta_sequences(filepath):
    """
    Reads a FASTA file and returns a dictionary of {header: sequence}.
    It assumes the user's specific single-line FASTA format is being used.
    """
    sequences = {}
    current_header = None
    current_sequence = []

    try:
        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue

                if line.startswith('>'):
                    if current_header and current_sequence:
                        sequences[current_header] = "".join(current_sequence)

                    # Store the new header, removing the '>'
                    # Use only the first part as header ID, as is typical for contig IDs
                    current_header = line[1:].split()[0]
                    current_sequence = []
                else:
                    # Append sequence lines, removing non-ACGT characters
                    current_sequence.append(re.sub(r'[^ACGTacgt]', '', line.upper()))

            # Yield the last sequence
            if current_header and current_sequence:
                sequences[current_header] = "".join(current_sequence)
    except FileNotFoundError:
        print(f"Error: File not found at {filepath}")
    except Exception as e:
        print(f"Error reading file {filepath}: {e}")

    return sequences


def find_all_matches_single_strand(sequence, regex_start, regex_end):
    """
    Finds ALL non-overlapping occurrences of the start motif followed by the
    end motif on a single sequence string.

    Returns a list of dictionaries containing match details.
    """
    matches = []
    current_search_start = 0
    seq_len = len(sequence)

    while current_search_start < seq_len:
        # 1. Search for the start primer
        match_start = re.search(regex_start, sequence[current_search_start:])

        if not match_start:
            break  # No more start motifs found

        # Adjust start match indices to be relative to the whole sequence
        start_index_0_based = current_search_start + match_start.start()
        search_for_end_from_index = current_search_start + match_start.end()

        # 2. Search for the end primer, starting immediately after the current start match
        match_end_in_substring = re.search(regex_end, sequence[search_for_end_from_index:])

        if match_end_in_substring:
            # Calculate indices in the whole sequence
            end_match_start_0_based = search_for_end_from_index + match_end_in_substring.start()
            end_of_segment_0_based_exclusive = search_for_end_from_index + match_end_in_substring.end()

            # Extract the motif sequences from the main sequence
            start_motif_seq = sequence[start_index_0_based: start_index_0_based + len(match_start.group(0))]
            end_motif_seq = sequence[end_match_start_0_based: end_of_segment_0_based_exclusive]

            # Extract the full amplicon sequence
            amplicon_sequence = sequence[start_index_0_based:end_of_segment_0_based_exclusive]

            matches.append({
                "amplicon_sequence": amplicon_sequence,
                "start_motif_seq": start_motif_seq,
                "end_motif_seq": end_motif_seq,
                "start_0": start_index_0_based,
                "end_0": end_of_segment_0_based_exclusive,
            })

            # Start the next search immediately after the end of the current full match
            # to ensure non-overlapping amplicons.
            current_search_start = end_of_segment_0_based_exclusive
        else:
            # If the start motif was found, but no end motif followed it,
            # we must advance the search past the current start motif's starting position
            # to look for the next possible pair.
            current_search_start = start_index_0_based + 1

    return matches


def find_and_extract(header, sequence, regex_start, regex_end):
    """
    Finds all non-overlapping regions on both forward and reverse strands.
    Reports coordinates relative to the original (forward) sequence.
    """
    all_results = []
    L = len(sequence)

    # --- 1. Search Forward Strand ---
    forward_matches = find_all_matches_single_strand(sequence, regex_start, regex_end)
    for m in forward_matches:
        all_results.append({
            "header": header,
            "strand": "FORWARD",
            # Coordinates are 1-based inclusive/exclusive
            "start_pos": m['start_0'] + 1,
            "end_pos": m['end_0'],
            "fwd_motif_seq": m['start_motif_seq'],
            "rev_motif_seq": m['end_motif_seq'],
            "amplicon_sequence": m['amplicon_sequence'],
        })

    # --- 2. Search Reverse Complement Strand ---
    # The primers are assumed to be oriented start->end relative to the template being amplified.
    # On the reverse complement sequence, the start primer matches the reverse end template,
    # and the end primer matches the reverse start template.
    # Therefore, we swap the regexes when searching the reverse complement sequence.
    rev_comp = reverse_complement(sequence)
    reverse_matches = find_all_matches_single_strand(rev_comp, regex_end, regex_start)

    for m in reverse_matches:
        # Calculate coordinates in the original (forward) sequence (1-based)
        # Match (R_start to R_end) in rev_comp corresponds to segment
        # (L - R_end) to (L - R_start) in the forward sequence.

        original_start_pos = L - m['end_0'] + 1
        original_end_pos = L - m['start_0']

        # The extracted sequence is the reverse complement amplicon, which is what the user wants.
        # Note: The start motif in the rev_comp search (regex_end) corresponds to the
        # reverse primer in the original sequence, and vice versa.

        all_results.append({
            "header": header,
            "strand": "REVERSE",
            "start_pos": original_start_pos,
            "end_pos": original_end_pos,
            "fwd_motif_seq": m['end_motif_seq'],  # Start motif (regex_end) matches the reverse primer
            "rev_motif_seq": m['start_motif_seq'],  # End motif (regex_start) matches the forward primer
            "amplicon_sequence": m['amplicon_sequence'],
        })

    # NOTE on Reverse Match Motif Labeling:
    # On the REVERSE strand, the 'primer_end' (TCNGCN...) acts as the FORWARD match,
    # and 'primer_start' (TTYRTN...) acts as the REVERSE match.
    # The labels in the output are based on the sequence they MATCHED in the original context:
    #   - fwd_matched_window_sequence: The sequence matching the TTYRTN... primer.
    #   - rev_matched_window_sequence: The sequence matching the TCNGCN... primer.
    # Since the coordinates are reported on the forward strand, we should report the actual
    # matched sequence in the context of the amplicon structure.
    # To keep the labels consistent with the user's columns:
    # 1. Fwd match: The sequence that matched the 'primer_start' regex.
    # 2. Rev match: The sequence that matched the 'primer_end' regex.
    # The current implementation correctly handles this by swapping the motif sequences
    # for the reverse match (since the order of regexes was swapped).

    return all_results


def main():
    parser = argparse.ArgumentParser(
        description="Search for all non-overlapping regions defined by two degenerate DNA sequences in FASTA files. Reports metadata (including matched sequences) in a TSV file."
    )
    # Required positional arguments
    parser.add_argument(
        "fasta_pattern",
        type=str,
        help="A file path pattern to match input FASTA files (e.g., 'assembly/*.fna.single.fasta')."
    )
    parser.add_argument(
        "output",
        type=str,
        help="The name of the output TSV file."
    )
    parser.add_argument(
        "primer_start",
        type=str,
        help="The degenerate sequence for the start motif (e.g., 'TTYRTNGAYAAYATCTWYCG')."
    )
    parser.add_argument(
        "primer_end",
        type=str,
        help="The degenerate sequence for the end motif (e.g., 'TCNGCNGTNGGNTAYCARCC')."
    )

    args = parser.parse_args()

    # Get primers from arguments
    primer_start = args.primer_start
    primer_end = args.primer_end

    # Convert the degenerate sequences to their regex patterns
    regex_start = iupac_to_regex(primer_start)
    regex_end = iupac_to_regex(primer_end)

    print(f"Searching for regions defined by:")
    print(f"  Start Motif: {primer_start} -> Regex: {regex_start}")
    print(f"  End Motif:   {primer_end} -> Regex: {regex_end}")

    # Find all matching files
    file_paths = glob(args.fasta_pattern)

    if not file_paths:
        print(f"Warning: No files found matching the pattern '{args.fasta_pattern}'.")
        return

    # Process all found files and write results
    total_found = 0

    # Open the output file for TSV writing
    with open(args.output, 'w', newline='') as outfile:
        # Create a CSV writer that uses a tab ('\t') as a delimiter
        tsv_writer = csv.writer(outfile, delimiter='\t')

        # Write the header row
        header_row = [
            "filename",
            "contig accession",
            "strand",
            "amplicon start",
            "amplicon end",
            "fwd matched window sequence",
            "rev matched window sequence",
            "amplicon sequence"
        ]
        tsv_writer.writerow(header_row)

        for filepath in file_paths:
            # Extract only the filename from the path
            filename = os.path.basename(filepath)
            print(f"Processing {filename}...")

            sequences = read_fasta_sequences(filepath)

            for header, sequence in sequences.items():
                # find_and_extract now returns a list of ALL matches
                results = find_and_extract(header, sequence, regex_start, regex_end)

                for result in results:
                    total_found += 1

                    # Write the data row to the TSV file
                    data_row = [
                        filename,
                        result['header'],
                        result['strand'],
                        result['start_pos'],
                        result['end_pos'],
                        result['fwd_motif_seq'],
                        result['rev_motif_seq'],
                        result['amplicon_sequence']
                    ]
                    tsv_writer.writerow(data_row)

                    print(
                        f"  -> Match found in {result['header']} (Strand: {result['strand']}, Position: {result['start_pos']}-{result['end_pos']})")

    print("-" * 50)
    print(f"Done. Found {total_found} total extracted regions across {len(file_paths)} files.")
    print(f"Results saved to TSV file: {args.output}")


if __name__ == "__main__":
    main()