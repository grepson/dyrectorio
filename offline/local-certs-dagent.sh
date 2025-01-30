#!/bin/sh

# Check if both curl command and cert path are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <curl_command> <path_to_host_cert>"
    echo "Example: $0 'curl -sL https://dyrectorio.home.arpa/api/dev/nodes/3ba12632-a62a-44eb-9ff3-1dc195c8ee1f/script | sh -' /etc/ssl/certs/ca.crt"
    exit 1
fi

CURL_COMMAND="$1"
HOST_CERT_PATH="$2"

# Check if the certificate exists
if [ ! -f "$HOST_CERT_PATH" ]; then
    echo "Warning: Certificate file not found at $HOST_CERT_PATH"
    echo "The script will be modified, but make sure the certificate exists when running the modified script"
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
TEMP_SCRIPT="$TEMP_DIR/install.sh"

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}

# Set trap for cleanup
trap cleanup EXIT

# Just extract the URL part between curl arguments and pipe
URL=$(echo "$1" | grep -o 'https://.*script')
if [ -z "$URL" ]; then
    echo "Error: Could not extract URL from curl command"
    exit 1
fi

# Download the script
echo "Downloading script from $URL..."
if ! curl -sL "$URL" > "$TEMP_SCRIPT"; then
    echo "Error: Failed to download script"
    exit 1
fi

# Make the script executable
chmod +x "$TEMP_SCRIPT"

# Use sed to modify the CRI run command
# We look for the line with "$CRI_EXECUTABLE run" and add our new parameters before the image name
sed -i.bak '
/\$CRI_EXECUTABLE run \\/,/-d / {
    /-d / i\
    -e SSL_CERT_FILE=/etc/certs/ca.crt \\\
    -v '"$HOST_CERT_PATH"':/etc/certs/ca.crt \\
}' "$TEMP_SCRIPT"

if [ $? -ne 0 ]; then
    echo "Error: Failed to modify the script"
    exit 1
fi

# Run script from tmp
sh ${TEMP_SCRIPT}

# After successful execution remove the script
rm ${TEMP_SCRIPT}
