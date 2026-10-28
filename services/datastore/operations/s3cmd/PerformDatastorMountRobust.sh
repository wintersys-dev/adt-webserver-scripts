#!/bin/sh
#########################################################################################
# Author:      Peter Winter
# Date:        9/4/2021 (POSIX Refactor 2026)
# Tool/Script: Automated S3 Datastore Mounting/Creation utility
# Suite:       The Agile Deployment Toolkit
# 
# Description: This script automates the mounting of an S3 datastore
#
# Arguments:
#              $1 - <datastore_to_mount> : Datastore to be mounted
#              $2 - <count>              : Integer ID used to select the rclone config profile.
##########################################################################################

# Exit immediately if a command exits with a non-zero status
set -e

# --- Functions ---
log_error() {
    echo "Error: $1" >&2
}

# Portable dependency check using 'command -v'
check_dependency() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_error "Required command '$1' is not installed or not in PATH."
        exit 1
    fi
}

# --- Validation ---
# Verify required binaries exist on the system
check_dependency grep
check_dependency awk
check_dependency sed
check_dependency s3cmd

# Validate presence of positional arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    log_error "2 arguments are required."
    echo "Usage: $0 <datastore_to_mount> <count>" >&2
    exit 1
fi

datastore_to_mount="$1"
count="$2"
s3_config="/root/.s3cfg-${count}"

# Verify the S3 configuration file exists and is readable
if [ ! -f "$s3_config" ]; then
    log_error "S3 configuration file not found: $s3_config"
    exit 1
fi

# --- Main Logic ---

# Extract host_base cleanly, ensuring quotes protect against whitespace issues
host_base=$(grep '^host_base' "$s3_config" | awk -F'=' '{print $NF}' | sed 's/ //g')

if [ -z "$host_base" ]; then
    log_error "Could not extract 'host_base' from $s3_config"
    exit 1
fi

# Disable 'set -e' temporarily so the script doesn't instantly crash if 's3cmd ls' fails
set +e
s3cmd --config="$s3_config" --host="https://${host_base}" ls "s3://${datastore_to_mount}" >/dev/null 2>&1
bucket_status=$?
set -e

# If the bucket does not exist (non-zero exit code), attempt to create it
if [ "$bucket_status" -ne 0 ]; then
    echo "Bucket s3://${datastore_to_mount} not found. Attempting to create..."
    
    # Silence output but safely handle creation failures
    if ! s3cmd --config="$s3_config" --host="https://${host_base}" mb "s3://${datastore_to_mount}" >/dev/null; then
        log_error "Failed to create bucket s3://${datastore_to_mount}"
        exit 1
    fi
    echo "Successfully created bucket s3://${datastore_to_mount}"
else
    echo "Bucket s3://${datastore_to_mount} already exists."
fi
