import sys
from collections import Counter
import statistics
# Corrected import: 'mt' is the alias for MeltingTemp
from Bio.SeqUtils import MeltingTemp as mt
from Bio.Seq import Seq

# --- Configuration Parameters ---
WINDOW_SIZE = 20
UPPER_THRESHOLD = 18
CANONICAL_BASES = {'A', 'T', 'C', 'G'}

# Ambiguity Sets for Counting
NBDHV_BASES = {'N', 'B', 'D', 'H', 'V'}
RYSWKM_BASES = {'R', 'Y', 'S', 'W', 'K', 'M'}

# Set of all valid IUPAC codes for robust checking
VALID_IUPAC_CODES = CANONICAL_BASES.union(NBDHV_BASES, RYSWKM_BASES)


def analyze_consensus(file_path, enrichment_threshold):
    """
    Main analysis function using Biopython's MeltingTemp for accurate Tm calculation,
    with robust error logging to stderr.
    """
    header = ''
    sequence = ''

    # File reading and setup (omitted for brevity, assume correct)
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
        # NOTE: This error should be raised at the top of the file but kept here for completeness
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
        # FIX 2: Define position at the start of the loop
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

                # --- 5. Tm Calculation using Biopython ---
                min_tm, avg_tm, max_tm = "N/A", "N/A", "N/A"

                # Check for characters that Biopython will reject
                has_invalid_char = any(base not in VALID_IUPAC_CODES for base in upper_window)

                if has_invalid_char:
                    min_tm, avg_tm, max_tm = "INVALID_CHAR", "INVALID_CHAR", "INVALID_CHAR"
                elif has_gap:
                    min_tm, avg_tm, max_tm = "CONTAINS_GAP", "CONTAINS_GAP", "CONTAINS_GAP"
                else:
                    # Only proceed if the window is clean
                    seq_obj = Seq(upper_window)

                    try:
                        # FIX 1: Use the correct Biopython function name for ambiguous sequences
                        tm_values = mt.Tm_for_AA(seq_obj)

                        if tm_values:
                            min_tm = min(tm_values)
                            max_tm = max(tm_values)
                            avg_tm = statistics.mean(tm_values)

                            min_tm = f"{min_tm:.2f}"
                            max_tm = f"{max_tm:.2f}"
                            avg_tm = f"{avg_tm:.2f}"

                    except Exception as e:
                        # Log error to stderr
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