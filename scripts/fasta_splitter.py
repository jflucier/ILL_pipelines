import re
import os
import sys
import argparse


def split_fasta_by_header(input_file, output_dir, prefix):
    """
    Splits a FASTA file into multiple files based on a component in the header,
    using the functional annotation captured by the regex: r'^(.*)___Bacteria_71___.*'
    """

    # Ensure the output directory exists
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"Created output directory: {output_dir}")

    # Regex to capture the functional annotation (e.g., 'OSCP', 'ATP-synt')
    # Captures the text before '___Bacteria_71___'
    HEADER_PATTERN = re.compile(r'^>([^_]*)___Bacteria_71___.*')

    # A dictionary to hold the file handles for writing
    file_handles = {}

    # Track which FASTA component is currently being processed
    current_name = None
    records_written = 0

    try:
        with open(input_file, 'r') as infile:
            for line in infile:
                # Check for a header line
                if line.startswith('>'):
                    match = HEADER_PATTERN.match(line)

                    if match:
                        # 1. Extract the captured group (e.g., 'OSCP')
                        raw_name = match.group(1)

                        # 2. Sanitize the name for use as a filename
                        safe_name = re.sub(r'[^\w\-.]', '_', raw_name)

                        current_name = safe_name

                        # 3. Get or create the output file handle
                        if current_name not in file_handles:
                            # Construct filename using the provided prefix
                            output_filename = f"{prefix}_{current_name}.fasta"
                            output_path = os.path.join(output_dir, output_filename)
                            file_handles[current_name] = open(output_path, 'w')

                        # Write the header line to the correct file
                        file_handles[current_name].write(line)
                        records_written += 1

                    else:
                        current_name = None  # Skip sequence if header doesn't match

                # Not a header line (must be a sequence line)
                elif current_name:
                    # Write the sequence line to the file corresponding to the last header
                    file_handles[current_name].write(line)

    except FileNotFoundError:
        print(f"FATAL: Input file '{input_file}' not found.", file=sys.stderr)
        sys.exit(1)

    finally:
        # Close all open file handles
        for fh in file_handles.values():
            fh.close()

        print("\nProcessing complete.")
        print(f"Total FASTA records written: {records_written}")
        print(f"Total unique FASTA files generated: {len(file_handles)}")


# -----------------------------------------------------------------------------
# Command Line Argument Handling
# -----------------------------------------------------------------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Splits a FASTA file based on the functional annotation in the header."
    )

    parser.add_argument(
        '-i', '--in',
        required=True,
        dest='input_fasta',
        help='The input FASTA file (e.g., syncom.align).'
    )

    parser.add_argument(
        '-o', '--outdir',
        required=True,
        dest='output_dir',
        help='The output directory where split FASTA files will be saved.'
    )

    parser.add_argument(
        '-p', '--prefix',
        required=True,
        dest='prefix',
        help='A prefix string for all outputted files (e.g., core_genes).'
    )

    args = parser.parse_args()

    split_fasta_by_header(
        input_file=args.input_fasta,
        output_dir=args.output_dir,
        prefix=args.prefix
    )