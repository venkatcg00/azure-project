#!/bin/bash
set -e

# -------------------------------
# Configuration Variables
# -------------------------------
# Installation directory for the MinIO binary
INSTALL_DIR="/opt/minio"
# Directory where MinIO will store its data (change as needed)
MINIO_DATA_DIR="/data/minio"
# URL to download the MinIO server binary
MINIO_BINARY_URL="https://dl.min.io/server/minio/release/linux-amd64/minio"
# Dedicated user for running MinIO
MINIO_USER="minio-user"
# Environment file to store MinIO options and credentials
ENV_FILE="/etc/default/minio"
# Systemd service file location
SERVICE_FILE="/etc/systemd/system/minio.service"

# Login credentials (customize as needed)
MINIO_ROOT_USER="minioadmin"
MINIO_ROOT_PASSWORD="minioadmin123"
# Additional options (set the console to port 9001)
MINIO_OPTS="--console-address :9001"

# Web UI URL to check (adjust host as needed; here we use localhost)
WEBUI_URL="http://localhost:9001"

# -------------------------------
# Update and Install Dependencies
# -------------------------------
echo "Updating system packages..."
apt update -y
apt upgrade -y
echo "Installing wget and curl..."
apt install -y wget curl

# -------------------------------
# Create Installation and Data Directories
# -------------------------------
echo "Creating installation directory at ${INSTALL_DIR}..."
mkdir -p "${INSTALL_DIR}"

echo "Creating MinIO data directory at ${MINIO_DATA_DIR}..."
mkdir -p "${MINIO_DATA_DIR}"

# -------------------------------
# Download and Install MinIO Binary
# -------------------------------
echo "Downloading MinIO binary from ${MINIO_BINARY_URL}..."
wget -q "${MINIO_BINARY_URL}" -O "${INSTALL_DIR}/minio"

echo "Setting execute permissions on the MinIO binary..."
chmod +x "${INSTALL_DIR}/minio"

# -------------------------------
# Create a Dedicated User for MinIO
# -------------------------------
if ! id -u "${MINIO_USER}" >/dev/null 2>&1; then
    echo "Creating dedicated user '${MINIO_USER}'..."
    useradd -r -s /sbin/nologin "${MINIO_USER}"
else
    echo "User '${MINIO_USER}' already exists."
fi

# -------------------------------
# Set Ownership of Directories
# -------------------------------
echo "Setting ownership of ${INSTALL_DIR} and ${MINIO_DATA_DIR} to ${MINIO_USER}..."
chown -R "${MINIO_USER}:${MINIO_USER}" "${INSTALL_DIR}"
chown -R "${MINIO_USER}:${MINIO_USER}" "${MINIO_DATA_DIR}"

# -------------------------------
# Create Environment File with Credentials and Options
# -------------------------------
echo "Creating environment file at ${ENV_FILE}..."
cat > "${ENV_FILE}" <<EOF
# MinIO environment configuration

# Data directory
MINIO_VOLUMES="${MINIO_DATA_DIR}"

# Additional options (e.g., setting the console address)
MINIO_OPTS="${MINIO_OPTS}"

# Login credentials
MINIO_ROOT_USER="${MINIO_ROOT_USER}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD}"
EOF

# -------------------------------
# Create systemd Service File
# -------------------------------
echo "Creating systemd service file at ${SERVICE_FILE}..."
cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=MinIO Object Storage Server
Documentation=https://docs.min.io
After=network.target

[Service]
User=${MINIO_USER}
Group=${MINIO_USER}
EnvironmentFile=${ENV_FILE}
ExecStart=${INSTALL_DIR}/minio server \$MINIO_OPTS \$MINIO_VOLUMES
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# -------------------------------
# Enable and Start MinIO Service
# -------------------------------
echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling MinIO service to start on boot..."
systemctl enable minio

echo "Starting MinIO service..."
systemctl start minio

echo "MinIO service status:"
systemctl status minio --no-pager

# -------------------------------
# Check if the Web UI is Accessible
# -------------------------------
echo ""
echo "Checking if the MinIO Web UI is accessible at ${WEBUI_URL} ..."
# Wait a few seconds to allow the service to fully start
sleep 5
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${WEBUI_URL}")

if [ "$HTTP_CODE" -eq 200 ]; then
    echo "Success: MinIO Web UI is accessible (HTTP 200)."
else
    echo "Warning: MinIO Web UI may not be accessible (HTTP code: ${HTTP_CODE})."
fi

# -------------------------------
# Display Login Credentials
# -------------------------------
echo ""
echo "========================================"
echo "MinIO Setup Complete!"
echo ""
echo "Login Credentials for the MinIO Web Interface:"
echo "  Username: ${MINIO_ROOT_USER}"
echo "  Password: ${MINIO_ROOT_PASSWORD}"
echo ""
echo "Access the MinIO Console at:"
echo "  ${WEBUI_URL}"
echo "========================================"
