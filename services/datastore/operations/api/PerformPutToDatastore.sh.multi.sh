#!/bin/sh

# ==============================================================================
# 1. Configuration parameters
# ==============================================================================
TOKEN='your_linode_personal_access_token_here'
CLUSTER_ID='us-east-1'
BUCKET_NAME='my-bucket'
OBJECT_KEY='backups/file.large'
FILE_TO_UPLOAD='/path/to/local/file.large'

# Part size for splitting (Linode requires minimum 5MB per part)
# 1000M = 1000 Megabytes (1 GB). Adjust based on your connection and file size.
PART_SIZE='1000M' 

# Temporary directory to store split file chunks (using current PID)
TMP_DIR='/tmp/linode_multipart_'$$
mkdir -p "$TMP_DIR"

# Cleanup function to remove chunks on exit or error
cleanup() {
  rm -rf "$TMP_DIR"
}
# Standard POSIX signal trapping (0 represents EXIT)
trap cleanup 0 1 2 15

# Validate file exists
if [ ! -f "$FILE_TO_UPLOAD" ]; then
  echo 'Error: Local file not found.'
  exit 1
fi

BASE_API='https://linode.com'"$CLUSTER_ID"'/'"$BUCKET_NAME"'/object-url'

# ==============================================================================
# 2. Split the file into manageable chunks
# ==============================================================================
echo 'Splitting file into chunks...'
# Splits file into parts named chunk_0000, chunk_0001, etc.
split -b "$PART_SIZE" -d -a 4 "$FILE_TO_UPLOAD" "${TMP_DIR}/chunk_"

# Use positional parameters to store the list of chunks cleanly in POSIX sh
set -- "${TMP_DIR}"/chunk_*
TOTAL_PARTS=$#

# Check if the first expansion actually exists to prevent literal glob matching strings
if [ ! -f "$1" ]; then
  echo 'Error: Failed to split file.'
  exit 1
fi

echo 'Total parts to upload: '"$TOTAL_PARTS"

# ==============================================================================
# 3. Initiate Multipart Upload Session
# ==============================================================================
echo 'Initiating multipart upload...'
INIT_RES=$(curl -s -X POST \
  -H 'Authorization: Bearer '"$TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name": "'"$OBJECT_KEY"'", "method": "POST"}' \
  "$BASE_API")

# We will collect the ETag headers returned by each part upload to build the final manifest.
PARTS_MANIFEST='['

# ==============================================================================
# 4. Upload each chunk sequentially
# ==============================================================================
PART_NUM=1

while [ "$PART_NUM" -le "$TOTAL_PARTS" ]; do
  # Fetch the path of the current chunk from positional parameters
  CHUNK_FILE=$1
  shift # Shift positional parameters down ($2 becomes $1)

  echo 'Processing part '"$PART_NUM"' of '"$TOTAL_PARTS"'...'

  # Request a unique signed PUT URL for this specific part number
  URL_RES=$(curl -s -X POST \
    -H 'Authorization: Bearer '"$TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"name": "'"$OBJECT_KEY"'", "method": "PUT", "part_number": '"$PART_NUM"'}' \
    "$BASE_API")

  UPLOAD_URL=$(echo "$URL_RES" | jq -r '.url')

  if [ "$UPLOAD_URL" = 'null' ] || [ -z "$UPLOAD_URL" ]; then
    echo 'Error: Failed to get upload URL for part '"$PART_NUM"
    exit 1
  fi

  # Upload the chunk and capture the response headers to get the ETag
  HEADER_FILE="${TMP_DIR}/headers_$PART_NUM.txt"
  
  curl -s -S -X PUT \
    -H 'Content-Type: application/octet-stream' \
    --upload-file "$CHUNK_FILE" \
    -D "$HEADER_FILE" \
    "$UPLOAD_URL"

  if [ $? -ne 0 ]; then
    echo 'Error: Upload failed for part '"$PART_NUM"
    exit 1
  fi

  # Extract ETag from headers (normalize line endings and quotes) using standard POSIX tr syntax
  ETAG=$(grep -i 'etag:' "$HEADER_FILE" | awk '{print $2}' | tr -d '\r\n"')
  
  if [ -z "$ETAG" ]; then
    echo 'Error: Could not retrieve ETag for part '"$PART_NUM"
    exit 1
  fi

  # Append to JSON manifest string
  if [ "$PART_NUM" -gt 1 ]; then
    PARTS_MANIFEST="${PARTS_MANIFEST},"
  fi
  PARTS_MANIFEST="${PARTS_MANIFEST}"'{"part_number":'"$PART_NUM"',"etag":"'"$ETAG"'"}'

  # Increment part counter using standard POSIX arithmetic expansion
  PART_NUM=$((PART_NUM + 1))
done

PARTS_MANIFEST="${PARTS_MANIFEST}"']'

# ==============================================================================
# 5. Complete Multipart Upload Session
# ==============================================================================
echo 'Completing multipart upload...'

COMPLETE_RES=$(curl -s -X POST \
  -H 'Authorization: Bearer '"$TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"name": "'"$OBJECT_KEY"'", "method": "POST", "parts": '"$PARTS_MANIFEST"'}' \
  "$BASE_API")

# Check success criteria
if echo "$COMPLETE_RES" | jq -e '.errors' >/dev/null 2>&1; then
  echo 'Error: Finalizing multipart upload failed.'
  echo "$COMPLETE_RES" | jq '.errors'
  exit 1
else
  echo 'Success! Large file uploaded successfully using multipart chunking.'
fi
