import sys
from collections import Counter

# --- Configuration Parameters ---
WINDOW_SIZE = 20
UPPER_THRESHOLD = 18  # Fixed for this script, but easily made an argument
CANONICAL_BASES = {'A', 'T', 'C', 'G'}
NBDHV_BASES = {'N', 'B', 'D', 'H', 'V'}


def analyze_consensus(file_path, enrichment_threshold):
    """
    Reads a FASTA consensus sequence, slides a window, and outputs windows that
    meet high uppercase (confidence) and canonical base (enrichment) thresholds.
    """
    header = ''
    sequence = ''

    # 1. File Reading
    try:
        with open(file_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith('>'):
                    if not header:
                        header = line[1:].strip()
                else:
                    sequence += line
    except FileNotFoundError:
        print(f"Error: File not found at {file_path}", file=sys.stderr)
        return

    sequence_length = len(sequence)
    if sequence_length < WINDOW_SIZE:
        print("Error: Sequence is shorter than the window size.", file=sys.stderr)
        return

    matching_windows = 0

    # --- Print Header Information ---
    print(f"## Sequence length: {sequence_length}")
    print(f"## 20 NT Window Analysis: {header}")
    print(f"## Thresholds: Upper Case >= {UPPER_THRESHOLD}; Canonical Count Check >= {enrichment_threshold}")
    print("-" * 120)
    print("Position\tA_Count\tT_Count\tC_Count\tG_Count\tUpper_Count\tNBDHV_Count\tWindow_Sequence")
    print("-" * 120)

    # 2. Slide the window across the sequence
    max_i = sequence_length - WINDOW_SIZE + 1
    for i in range(max_i):
        window = sequence[i: i + WINDOW_SIZE]

        upper_count = 0
        canonical_bases = []
        nbdhv_count = 0

        # 3. Analyze the window character by character
        for char in window:
            if 'A' <= char <= 'Z':
                upper_count += 1

            base = char.upper()

            if base in NBDHV_BASES:
                nbdhv_count += 1

            if base in CANONICAL_BASES:
                canonical_bases.append(base)

        # Calculate base counts and total canonical count (used for enrichment filter)
        counts = Counter(canonical_bases)
        total_canonical_count = len(canonical_bases)

        # 4. Check thresholds (using the passed parameter)
        if upper_count >= UPPER_THRESHOLD:
            # Check canonical count against the user-defined ENRICHMENT_THRESHOLD
            if total_canonical_count >= enrichment_threshold:
                # 5. Print the results
                position = i + 1

                print(f"{position}\t"
                      f"{counts.get('A', 0)}\t"
                      f"{counts.get('T', 0)}\t"
                      f"{counts.get('C', 0)}\t"
                      f"{counts.get('G', 0)}\t"
                      f"{upper_count}\t"
                      f"{nbdhv_count}\t"
                      f"{window}"
                      )
                matching_windows += 1

    print("-" * 120)
    print(f"## Analysis Complete. Total windows checked: {max_i}. Matching windows found: {matching_windows}")
    print("-" * 120)


if __name__ == '__main__':
    # 1. Check for exactly two arguments (script name + file + threshold)
    if len(sys.argv) != 3:
        print("Usage: python script_name.py <consensus_fasta_file> <ENRICHMENT_THRESHOLD>", file=sys.stderr)
        sys.exit(1)

    file_path = sys.argv[1]

    # 2. Attempt to parse the threshold argument
    try:
        # The threshold must be an integer
        enrichment_threshold = int(sys.argv[2])
    except ValueError:
        print("Error: ENRICHMENT_THRESHOLD must be an integer.", file=sys.stderr)
        sys.exit(1)

    analyze_consensus(file_path, enrichment_threshold)