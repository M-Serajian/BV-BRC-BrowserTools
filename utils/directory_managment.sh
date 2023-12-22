#!/bin/bash

create_directory() {
  local directory=$1
  echo Creating following directory
  echo $directory
  # Check if the directory exists
  if [ -d "$directory" ]; then
    echo -e "\e[34mThe directory '$directory' already exists.\e[0m"  # Blue text
  else
    # Try to create the directory
    mkdir -p "$directory"

    # Check if the directory creation was successful
    if [ $? -eq 0 ]; then
      echo -e "\e[32mThe directory '$directory' has been created.\e[0m"  # Green text
    else
      echo -e "\e[31mError: The directory '$directory' could not be created.\e[0m"  # Red text
      echo -e "\e[31mProgram aborted!\e[0m"  # Red text 
      exit 2  # Abort the script with an error status
    fi
  fi
}
# this function grants Read, Write, and Execute permissions 
grant_permissions() {

    local directory="$1" #Input of the function, a local valiable

    if [ -d  "${directory}" ]; then
        # Permissions granted successfully
        echo -e "\e[33mRead, Write, and Execute permissions granted to the group"\
                "for the following directory:\e[0m"
        echo -e "\e[33m${directory}\e[0m"
    else
        # Command failed
        echo -e "\e[31mPermission could not be granted for the group in the following directory:\e[0m"  # Red text
        echo -e "\e[31m${directory}\e[0m"
        echo -e "\e[31mProgram aborted!\e[0m"
        exit 2
    fi
}
