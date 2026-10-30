#!/bin/sh
set -e


if [ -f /home/homedir.dat ]
then
    HOME="$(/bin/cat /home/homedir.dat)"
else
    /bin/echo "Error: /home/homedir.dat missing."
    log_error "Configuration file /home/homedir.dat is missing."
    exit 1
fi

# Configuration: Set your log file location here
LOG_FILE="${HOME}/logs/datastore/datastore_activity.log"

# Function to write errors safely
log_error() {
    /bin/echo "[$(/bin/date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# 1. Check for all 4 arguments safely
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]
then
    /bin/echo "Error: 4 arguments are required."
    /bin/echo "Usage: $0 <file_to_put> <place_to_put> <delete> <count>"
    log_error "Script invoked with missing arguments."
    exit 1
fi

file_to_put="$1"
place_to_put="$2"
delete="$3"
count="$4"

place_to_put="${place_to_put%root}"

WORK_AREA="${HOME}/runtime/datastore_workarea"
if [ ! -d "$WORK_AREA" ]
then
    /bin/mkdir -p "$WORK_AREA"
fi

if [ ! -f "$file_to_put" ]
then
    /bin/touch "$WORK_AREA/$file_to_put"
    file_to_put_with_path="$WORK_AREA/$file_to_put"
else
    file_to_put_with_path="$file_to_put"
fi

filename="${file_to_put_with_path##*/}"
place_to_put="${place_to_put%/}"

cfg_file="/root/.s5cfg-${count}"
if [ ! -f "$cfg_file" ]
then
    /bin/echo "Error: Configuration profile $cfg_file not found."
    log_error "Profile configuration file missing: $cfg_file"
    exit 1
fi

host_base=$(/usr/bin/grep ^host_base "$cfg_file" | /usr/bin/awk -F'=' '{print $NF}' | /usr/bin/tr -d ' ')

set +e
/usr/bin/s5cmd --credentials-file "$cfg_file" --endpoint-url "https://${host_base}" cp "$file_to_put_with_path" "s3://${place_to_put}/${filename}" 2>/dev/null
s5cmd_status=$?
set -e

if [ $s5cmd_status -ne 0 ]
then
    /bin/echo "Failed to put ${filename} to s3://${place_to_put}"
    log_error "s5cmd failed to upload ${filename} to s3://${place_to_put} (Exit code: $s5cmd_status)"
    exit 1
fi

if [ "$delete" = "yes" ]
then
    if [ -f "$file_to_put_with_path" ]
    then
        /bin/rm "$file_to_put_with_path"
    fi
fi

exit 0
