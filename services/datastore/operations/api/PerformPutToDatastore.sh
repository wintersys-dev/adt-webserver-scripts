#!/bin/sh

# 1. Configuration parameters
TOKEN="your_linode_personal_access_token_here"
CLUSTER_ID="us-east-1"      # The Linode region cluster where your bucket lives
BUCKET_NAME="my-bucket"     # Your destination bucket name
OBJECT_KEY="backups/file.txt" # The destination path inside your bucket
FILE_TO_UPLOAD="/path/to/local/file.txt"

# 2. Request a secure, temporary upload URL from the Linode API (Valid for 10 minutes)
echo "Generating secure upload URL from Linode API..."
#API_RESPONSE=$(curl -s -X POST \
 # -H "Authorization: Bearer $LINODE_TOKEN" \
 # -H "Content-Type: application/json" \
 # -d "{\"name\": \"$OBJECT_KEY\", \"method\": \"PUT\"}" \
 # "https://linode.com")

  
API_RESPONSE="`curl -s -X POST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"name": "$OBJECT_KEY", "method": "PUT"}" "https://api.linode.com/v4/object-storage/buckets/${CLUSTER_ID}/${BUCKET_NAME}"'`"

# Extract the temporary URL string from the JSON response
UPLOAD_URL=$(echo "$API_RESPONSE" | jq -r '.url')

if [ "$UPLOAD_URL" = "null" ] || [ -z "$UPLOAD_URL" ]; then
    echo "Error: Failed to obtain API upload URL from Linode."
    echo "Response from API: $API_RESPONSE"
    exit 1
fi

# 3. Stream the file binary data directly to the temporary URL endpoint
echo "Streaming file data to Linode Object Storage..."
curl -s -X PUT \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@$FILE_TO_UPLOAD" \
  "$UPLOAD_URL"

if [ $? -eq 0 ]; then
    echo "Success! File uploaded completely via native Linode API."
else
    echo "Error: Data upload failed."
    exit 1
fi
