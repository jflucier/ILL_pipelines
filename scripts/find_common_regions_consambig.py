import sys
from collections import Counter

# --- Configuration Parameters ---
WINDOW_SIZE = 20
UPPER_THRESHOLD = 18  # At least 18 out of 20 NT must be uppercase (High Confidence)
ENRICHMENT_THRESHOLD = 13  # At least 15 out of 20 NT must be canonical (A, T, C, G)
CANONICAL_BASES = {'A', 'T', 'C', 'G'}


def analyze_consensus(file_path):
    # ... (File reading and setup remains the same) ...
    header = ''
    sequence = ''
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
    print(f"## Thresholds: Upper Case >= {UPPER_THRESHOLD}; Total Canonical Base Count >= {ENRICHMENT_THRESHOLD}")
    print("-" * 120)
    # UPDATED HEADER: Added Window_Sequence column
    print("Position\tA_Count\tT_Count\tC_Count\tG_Count\tUpper_Count\tTotal_Canonical_Count\tWindow_Sequence")
    print("-" * 120)

    # 2. Slide the window across the sequence
    max_i = sequence_length - WINDOW_SIZE + 1
    for i in range(max_i):
        window = sequence[i: i + WINDOW_SIZE]

        upper_count = 0
        canonical_bases = []

        # 3. Analyze the window character by character
        for char in window:
            if 'A' <= char <= 'Z':
                upper_count += 1

            base = char.upper()
            if base in CANONICAL_BASES:
                canonical_bases.append(base)

        # Calculate counts and total
        counts = Counter(canonical_bases)
        total_canonical_count = len(canonical_bases)

        # 4. Check thresholds
        if upper_count >= UPPER_THRESHOLD:
            if total_canonical_count >= ENRICHMENT_THRESHOLD:
                # 5. Print the results for the current window
                position = i + 1

                # UPDATED PRINT: Added the window variable at the end
                print(f"{position}\t"
                      f"{counts.get('A', 0)}\t"
                      f"{counts.get('T', 0)}\t"
                      f"{counts.get('C', 0)}\t"
                      f"{counts.get('G', 0)}\t"
                      f"{upper_count}\t"
                      f"{total_canonical_count}\t"
                      f"{window}"  # <--- NEW COLUMN
                      )
                matching_windows += 1

    print("-" * 120)
    print(f"## Analysis Complete. Total windows checked: {max_i}. Matching windows found: {matching_windows}")
    print("-" * 120)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python script_name.py <consensus_fasta_file>", file=sys.stderr)
        sys.exit(1)

    file_path = sys.argv[1]
    analyze_consensus(file_path)