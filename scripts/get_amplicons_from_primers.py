import re
import os
import argparse
from glob import glob
import csv
from Bio.Seq import Seq
from Bio.SeqUtils import MeltingTemp as mt

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
        # 1. Search for the start primer (regex_start)
        match_start = re.search(regex_start, sequence[current_search_start:])

        if not match_start:
            break  # No more start motifs found

        # Adjust start match indices to be relative to the whole sequence
        start_index_0_based = current_search_start + match_start.start()
        search_for_end_from_index = current_search_start + match_start.end()

        # 2. Search for the end primer (regex_end), starting immediately after the current start match
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


def find_and_extract(header, sequence, regex_start, regex_end, primer_start, primer_end):
    """
    Finds all non-overlapping regions on both forward and reverse strands, checking both motif orders (P1..P2 and P2..P1).
    Reports coordinates relative to the original (forward) sequence.
    """
    all_results = []
    L = len(sequence)
    rev_comp = reverse_complement(sequence)

    # Define the four search combinations: (Template, Upstream_Regex, Downstream_Regex, Strand, Upstream_Primer_Input, Downstream_Primer_Input)
    search_combinations = [
        # 1. Forward Template, Order P_start..P_end
        (sequence, regex_start, regex_end, "FORWARD", primer_start, primer_end),

        # 2. Forward Template, Order P_end..P_start
        (sequence, regex_end, regex_start, "FORWARD", primer_end, primer_start),

        # 3. Reverse Template, Order P_start..P_end (RC matches)
        (rev_comp, regex_start, regex_end, "REVERSE", primer_start, primer_end),

        # 4. Reverse Template, Order P_end..P_start (RC matches)
        (rev_comp, regex_end, regex_start, "REVERSE", primer_end, primer_start),
    ]

    for template, up_regex, down_regex, strand, up_primer_input, down_primer_input in search_combinations:

        current_matches = find_all_matches_single_strand(template, up_regex, down_regex)

        for m in current_matches:

            # --- Coordinate Calculation ---
            if strand == "FORWARD":
                # Coordinates are 1-based inclusive/exclusive
                start_pos = m['start_0'] + 1
                end_pos = m['end_0']
            else:  # strand == "REVERSE"
                # Calculate coordinates in the original (forward) sequence (1-based)
                # Match (R_start to R_end) in RC corresponds to segment (L - R_end) to (L - R_start) in FWD sequence.
                start_pos = L - m['end_0'] + 1
                end_pos = L - m['start_0']

            # --- Matched Sequence Mapping ---
            # Map the motif sequences back to the original input primers (primer_start / primer_end)

            # If P_start was the UPSTREAM motif in this match:
            if up_primer_input == primer_start:
                fwd_match_seq = m['start_motif_seq']
                rev_match_seq = m['end_motif_seq']

            # If P_end was the UPSTREAM motif in this match:
            else:  # up_primer_input == primer_end
                fwd_match_seq = m['end_motif_seq']
                rev_match_seq = m['start_motif_seq']

            all_results.append({
                "header": header,
                "strand": strand,
                "start_pos": start_pos,
                "end_pos": end_pos,
                "fwd_match_seq": fwd_match_seq,  # Sequence that matched primer_start (P1)
                "rev_match_seq": rev_match_seq,  # Sequence that matched primer_end (P2)
                "amplicon_sequence": m['amplicon_sequence'],
            })

    return all_results


def calculate_tm(sequence):
    """Calculates the Melting Temperature (Tm) using the Nearest Neighbor method."""
    try:
        # **CORRECTION: Explicitly pass the DNA_NN4 table dictionary from mt.**
        # This bypasses potential issues where the internal lookup fails.
        # We also need to explicitly pass the default standard conditions (1 M salt, 0 M Mg2+).

        # Use the standard set of parameters defined in Biopython
        tm_value = mt.Tm_NN(
            Seq(sequence),
            nn_table=mt.DNA_NN4,  # Use the explicit dictionary object
        )

        # Return the value rounded to 2 decimal places
        return round(tm_value, 2)

    except KeyError as e:
        # This catches issues with sequence content (e.g., non-standard bases not handled
        # by the sequence filtering in the main script).
        return f"KeyError: {e}"

    except Exception as e:
        # Catch the generic error and return the specific exception type and message.
        # This will now tell you why the internal Tm_NN logic is failing.
        return f"Error: {type(e).__name__}: {e}"


def main():
    parser = argparse.ArgumentParser(
        description="Search for all non-overlapping regions defined by two degenerate DNA sequences in FASTA files. Performs a symmetrical search (P1..P2 and P2..P1) on both strands. Reports metadata (including matched sequences) in a TSV file."
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
        help="The degenerate sequence for the START motif (P1)."
    )
    parser.add_argument(
        "primer_end",
        type=str,
        help="The degenerate sequence for the END motif (P2)."
    )

    args = parser.parse_args()

    # Get primers from arguments
    primer_start = args.primer_start
    primer_end = args.primer_end

    output_filename = os.path.basename(args.output)

    # Convert the degenerate sequences to their regex patterns
    regex_start = iupac_to_regex(primer_start)
    regex_end = iupac_to_regex(primer_end)

    print(f"Searching for regions defined by motifs P1: '{primer_start}' and P2: '{primer_end}'")

    # Find all matching files
    file_paths = glob(args.fasta_pattern)

    if not file_paths:
        print(f"Warning: No files found matching the pattern '{args.fasta_pattern}'.")
        return

    # Process all found files and write results
    total_found = 0

    # Open the output file for TSV writing
    file_exists = os.path.exists(args.output)

    with open(args.output, 'a', newline='') as outfile:
        # Create a CSV writer that uses a tab ('\t') as a delimiter
        tsv_writer = csv.writer(outfile, delimiter='\t')

        # Write the header row ONLY if the file is new or empty
        if not file_exists or os.path.getsize(args.output) == 0:
            header_row = [
                "output file",
                "filename",
                "contig accession",
                "strand",
                "amplicon start",
                "amplicon end",
                "amplicon length", # <-- NEW HEADER
                f"P1 ({primer_start}) matched sequence",
                f"P2 ({primer_end}) matched sequence",
                f"Tm P1 ({primer_start})",
                f"Tm P2 ({primer_end})",
                "amplicon sequence"
            ]
            tsv_writer.writerow(header_row)

        for filepath in file_paths:
            # Extract only the filename from the path
            filename = os.path.basename(filepath)

            sequences = read_fasta_sequences(filepath)

            for header, sequence in sequences.items():
                results = find_and_extract(header, sequence, regex_start, regex_end, primer_start, primer_end)

                for result in results:
                    total_found += 1

                    # --- TM and LENGTH CALCULATION ---
                    tm_p1 = calculate_tm(result['fwd_match_seq'])
                    tm_p2 = calculate_tm(result['rev_match_seq'])
                    amplicon_length = len(result['amplicon_sequence'])
                    # --------------------------------

                    # Write the data row to the TSV file
                    data_row = [
                        output_filename,
                        filename,
                        result['header'],
                        result['strand'],
                        result['start_pos'],
                        result['end_pos'],
                        amplicon_length, # <-- NEW VALUE
                        result['fwd_match_seq'],  # Matched P1
                        result['rev_match_seq'],  # Matched P2
                        tm_p1,
                        tm_p2,
                        result['amplicon_sequence']
                    ]
                    tsv_writer.writerow(data_row)

            print(f"Finished processing {filename}. Matches found in this file.")

    print("-" * 50)
    print(f"Done. Found {total_found} total extracted regions across {len(file_paths)} files.")
    print(f"Results saved to TSV file: {args.output}")


if __name__ == "__main__":
    main()