#!/bin/bash

text_file_finder_and_sanity_checker_corrector() {
  local file_path=$1
  # Check if the file exists
  if [ -e "$file_path" ]; then
    if grep -q -E '^[\t ]*$' "$file_path"; then
    # Empty lines found, perform the process to remove them in-place
        # Use sed to remove empty lines in-place
        sed -i '/^[\t ]*$/d' "$file_path"
        echo "Empty lines removed in: $file_path"
        echo -e "\e[33mError: Empty lines removed in:'$file_path'.\e[0m"  # Red text
    fi

    # Check if the file is not empty
    if [ -s "$file_path" ]; then
      echo "The text file '$file_path' found!"
      # Do any additional processing here if needed
    else
      echo -e "\e[31mError: The text file '$file_path' is found but is empty.\e[0m"  # Red text
      echo -e "\e[31mProgram aborted!\e[0m"  # Red text
      exit 2  # Abort the script with an error status
    fi

  else
    echo -e "\e[31mError: The text file '$file_path' could not be found.\e[0m"  # Red text
    echo -e "\e[31mProgram aborted!\e[0m"  # Red text
    exit 2  # Abort the script with an error status
  fi
}

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
