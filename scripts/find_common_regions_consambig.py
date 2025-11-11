import sys
from collections import Counter

# --- Configuration Parameters ---
WINDOW_SIZE = 20
UPPER_THRESHOLD = 18
ENRICHMENT_THRESHOLD = 15
CANONICAL_BASES = {'A', 'T', 'C', 'G'}

# Set 1: Ambiguity codes for NBDHV_Count
NBDHV_BASES = {'N', 'B', 'D', 'H', 'V'}
# Set 2: Ambiguity codes for RYSWKM_Count
RYSWKM_BASES = {'R', 'Y', 'S', 'W', 'K', 'M'}


def analyze_consensus(file_path, enrichment_threshold):
    """
    Reads a FASTA consensus sequence, slides a window, and outputs windows that
    meet high uppercase (confidence) and canonical base (enrichment) thresholds,
    including separate counts for two groups of ambiguity codes (NBDHV and RYSWKM).
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
    print("-" * 140)
    # UPDATED HEADER: Includes NBDHV_Count and RYSWKM_Count as separate columns
    print("Position\tA_Count\tT_Count\tC_Count\tG_Count\tUpper_Count\tNBDHV_Count\tRYSWKM_Count\tWindow_Sequence")
    print("-" * 140)

    # 2. Slide the window across the sequence
    max_i = sequence_length - WINDOW_SIZE + 1
    for i in range(max_i):
        window = sequence[i: i + WINDOW_SIZE]

        upper_count = 0
        canonical_bases = []
        nbdhv_count = 0  # Counter for N, B, D, H, V
        ryswkm_count = 0  # Counter for R, Y, S, W, K, M

        # 3. Analyze the window character by character
        for char in window:
            if 'A' <= char <= 'Z':
                upper_count += 1

            base = char.upper()

            # Check for NBDHV characters
            if base in NBDHV_BASES:
                nbdhv_count += 1

            # Check for RYSWKM characters
            elif base in RYSWKM_BASES:
                ryswkm_count += 1

            if base in CANONICAL_BASES:
                canonical_bases.append(base)

        # Calculate base counts and total canonical count (used for enrichment filter)
        counts = Counter(canonical_bases)
        total_canonical_count = len(canonical_bases)

        # 4. Check thresholds (Conditions remain based on confidence and enrichment)
        if upper_count >= UPPER_THRESHOLD:
            if total_canonical_count >= enrichment_threshold:
                # 5. Print the results for the current window
                position = i + 1

                # UPDATED PRINT: Includes two new ambiguity count columns
                print(f"{position}\t"
                      f"{counts.get('A', 0)}\t"
                      f"{counts.get('T', 0)}\t"
                      f"{counts.get('C', 0)}\t"
                      f"{counts.get('G', 0)}\t"
                      f"{upper_count}\t"
                      f"{nbdhv_count}\t"  # <--- NBDHV COUNT (Column 7)
                      f"{ryswkm_count}\t"  # <--- RYSWKM COUNT (Column 8)
                      f"{window}"
                      )
                matching_windows += 1

    print("-" * 140)
    print(f"## Analysis Complete. Total windows checked: {max_i}. Matching windows found: {matching_windows}")
    print("-" * 140)


if __name__ == '__main__':
    # 1. Check for exactly two arguments (script name + file + threshold)
    if len(sys.argv) != 3:
        print("Usage: python script_name.py <consensus_fasta_file> <ENRICHMENT_THRESHOLD>", file=sys.stderr)
        sys.exit(1)

    file_path = sys.argv[1]

    # 2. Attempt to parse the threshold argument
    try:
        enrichment_threshold = int(sys.argv[2])
    except ValueError:
        print("Error: ENRICHMENT_THRESHOLD must be an integer.", file=sys.stderr)
        sys.exit(1)

    analyze_consensus(file_path, enrichment_threshold)