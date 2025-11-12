import sys
from collections import Counter
import statistics
from Bio.SeqUtils import MeltingTemp as mt
from Bio.Seq import Seq

# --- Configuration Parameters ---
WINDOW_SIZE = 20
UPPER_THRESHOLD = 18
CANONICAL_BASES = {'A', 'T', 'C', 'G'}

# Ambiguity Sets for Counting
NBDHV_BASES = {'N', 'B', 'D', 'H', 'V'}
RYSWKM_BASES = {'R', 'Y', 'S', 'W', 'K', 'M'}

# Set of all valid IUPAC codes
VALID_IUPAC_CODES = CANONICAL_BASES.union(NBDHV_BASES, RYSWKM_BASES)

# IUPAC Map for manual sequence expansion (used by the new function)
IUPAC_MAP = {
    'A': ['A'], 'T': ['T'], 'C': ['C'], 'G': ['G'],
    'R': ['A', 'G'], 'Y': ['C', 'T'], 'S': ['G', 'C'], 'W': ['A', 'T'],
    'K': ['G', 'T'], 'M': ['A', 'C'],
    'B': ['C', 'G', 'T'], 'D': ['A', 'G', 'T'],
    'H': ['A', 'C', 'T'], 'V': ['A', 'C', 'G'],
    'N': ['A', 'T', 'C', 'G'],
}


def generate_all_sequences(ambiguous_seq):
    """Recursively generates all unambiguous sequences from an ambiguous sequence."""
    if not ambiguous_seq:
        yield ""
        return

    first_base = ambiguous_seq[0]
    remaining_seq = ambiguous_seq[1:]

    # We already checked for validity, so this should not fail, but handled defensively.
    possible_bases = IUPAC_MAP.get(first_base, [first_base])

    for base in possible_bases:
        for sub_sequence in generate_all_sequences(remaining_seq):
            yield base + sub_sequence


def analyze_consensus(file_path, enrichment_threshold):
    """
    Main analysis function using Tm_NN for stability and manual iteration for min/avg/max Tm.
    """
    header = ''
    sequence = ''

    # File reading and setup (omitted for brevity)
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
    except ImportError:
        print("Error: Biopython is required. Please install it (e.g., pip install biopython).", file=sys.stderr)
        return

    sequence_length = len(sequence)
    if sequence_length < WINDOW_SIZE:
        print("Error: Sequence is shorter than the window size.", file=sys.stderr)
        return

    matching_windows = 0
    errors_logged = 0

    # --- Print Header Information ---
    print(f"## Sequence length: {sequence_length}")
    print(f"## 20 NT Window Analysis: {header}")
    print(f"## Thresholds: Upper Case >= {UPPER_THRESHOLD}; Canonical Count Check >= {enrichment_threshold}")
    print("-" * 160)
    print(
        "Position\tA_Count\tT_Count\tC_Count\tG_Count\tUpper_Count\tNBDHV_Count\tRYSWKM_Count\tWindow_Sequence\tMin_Tm\tAvg_Tm\tMax_Tm")
    print("-" * 160)

    # 2. Slide the window across the sequence
    max_i = sequence_length - WINDOW_SIZE + 1
    for i in range(max_i):
        position = i + 1
        window = sequence[i: i + WINDOW_SIZE]

        upper_count = 0
        canonical_bases = []
        nbdhv_count = 0
        ryswkm_count = 0
        has_gap = False

        upper_window = window.upper()

        # 3. Analyze the window character by character
        for char in window:
            if char == '-':
                has_gap = True

            if 'A' <= char <= 'Z':
                upper_count += 1

            base = char.upper()

            if base in NBDHV_BASES:
                nbdhv_count += 1
            elif base in RYSWKM_BASES:
                ryswkm_count += 1

            if base in CANONICAL_BASES:
                canonical_bases.append(base)

        counts = Counter(canonical_bases)
        total_canonical_count = len(canonical_bases)

        # 4. Check thresholds
        if upper_count >= UPPER_THRESHOLD:
            if total_canonical_count >= enrichment_threshold:

                # --- 5. Tm Calculation using Tm_NN ---
                min_tm, avg_tm, max_tm = "N/A", "N/A", "N/A"

                has_invalid_char = any(base not in VALID_IUPAC_CODES for base in upper_window)

                if has_invalid_char:
                    min_tm, avg_tm, max_tm = "INVALID_CHAR", "INVALID_CHAR", "INVALID_CHAR"
                elif has_gap:
                    min_tm, avg_tm, max_tm = "CONTAINS_GAP", "CONTAINS_GAP", "CONTAINS_GAP"
                else:
                    try:
                        # Manually generate all sequences and calculate Tm for each
                        all_sequences = list(generate_all_sequences(upper_window))
                        tm_values = []

                        for seq in all_sequences:
                            # Use the robust, foundational Tm_NN function
                            tm_values.append(mt.Tm_NN(Seq(seq)))

                        if tm_values:
                            min_tm = min(tm_values)
                            max_tm = max(tm_values)
                            avg_tm = statistics.mean(tm_values)

                            min_tm = f"{min_tm:.2f}"
                            max_tm = f"{max_tm:.2f}"
                            avg_tm = f"{avg_tm:.2f}"

                    except Exception as e:
                        errors_logged += 1
                        error_type = type(e).__name__
                        print(f"Tm ERROR @ Position {position} ({window}): [{error_type}] {e}", file=sys.stderr)
                        min_tm, avg_tm, max_tm = error_type, error_type, error_type

                # 6. Print the results for the current window
                print(f"{position}\t"
                      f"{counts.get('A', 0)}\t"
                      f"{counts.get('T', 0)}\t"
                      f"{counts.get('C', 0)}\t"
                      f"{counts.get('G', 0)}\t"
                      f"{upper_count}\t"
                      f"{nbdhv_count}\t"
                      f"{ryswkm_count}\t"
                      f"{window}\t"
                      f"{min_tm}\t"
                      f"{avg_tm}\t"
                      f"{max_tm}"
                      )
                matching_windows += 1

    print("-" * 160, file=sys.stderr)
    print(f"## Analysis Complete. Total windows checked: {max_i}. Matching windows found: {matching_windows}",
          file=sys.stderr)
    if errors_logged > 0:
        print(f"## WARNING: {errors_logged} Tm errors were logged to standard error (above).", file=sys.stderr)
    print("-" * 160, file=sys.stderr)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python script_name.py <consensus_fasta_file> <ENRICHMENT_THRESHOLD>", file=sys.stderr)
        sys.exit(1)

    file_path = sys.argv[1]

    try:
        enrichment_threshold = int(sys.argv[2])
    except ValueError:
        print("Error: ENRICHMENT_THRESHOLD must be an integer.", file=sys.stderr)
        sys.exit(1)

    analyze_consensus(file_path, enrichment_threshold)