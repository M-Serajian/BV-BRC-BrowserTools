#!/bin/bash

original_file="/home/m.serajian/projects/Patric_genome_downloader/Unique_Genome_IDs.txt"  # Replace with your actual file path


remove_downloaded_genomes_form_input_text() {
    local input_file="$1"
    local string_to_remove="$2"

    # Check if the input file exists
    if [ ! -f "$input_file" ]; then
        echo "Error: Input file '$input_file' not found."
        return 1
    fi

    # Use a background process to manage the lock without creating a lock file
    {
        flock -x 9

        # Use sed to remove lines containing the specified string in place
        sed -i "/$string_to_remove/d" "$input_file"
    } 9<>"$input_file"

    # No need to release the lock or close file descriptor; it's done automatically
}

# Extract file information
suffix="${original_file##*.}"  # Extract suffix
base_name="${original_file%.*}"  # Extract base name

# Create the remaining file in the same directory as the original file
copy_file="${base_name}_remaining.txt"

# Create a copy of the original file
cp "$original_file" "$copy_file"

# Use sed to remove lines containing the specified patterns in place
#sed -i '/1733\.52/d; /1733\.10022/d; /1773\.20463/d' "$copy_file"

remove_downloaded_genomes_form_input_text $copy_file "1733.52"
