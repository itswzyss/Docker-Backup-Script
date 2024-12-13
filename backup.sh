#!/bin/bash

# Color codes for alerting
RED='\033[0;31m'
NC='\033[0m'  # No Color

# User-configurable backup settings
BACKUP_TYPE=2  # 1 for local-only, 2 for rclone
BACKUP_DIR="/backups"  # Local backup directory
REMOTE_BACKUP_DIR=""  # Remote backup directory (required for rclone). Expects rclone format i.e. [rclone remote]:[directory/bucket] - (b2:/backups)

# Maximum number of parallel threads
MAX_THREADS=3

# Ensure the local backup directory exists
if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "Creating local backup directory: $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
fi

# Define services and their related directories in one place. Multiple directories supported, just separate them with ":". See example below.
# Each service belongs on its own line.
SERVICES=(
  #"service_name:/service_directory:/additional_directory"
)

# Function to process a single service
process_service() {
  local SERVICE_ENTRY="$1"

  # Split the entry into service name and directories
  IFS=':' read -r SERVICE_NAME MAIN_DIR ADDITIONAL_DIRS <<< "$SERVICE_ENTRY"
  DIRECTORIES=($MAIN_DIR ${ADDITIONAL_DIRS//:/ })

  echo "Stopping containers in $SERVICE_NAME"

  cd "$MAIN_DIR" || { 
    echo -e "${RED}Failed to navigate to $MAIN_DIR. Exiting.${NC}"
    exit 1
  }

  # Stop all services in the directory
  docker compose stop
  if [[ $? -ne 0 ]]; then
    echo -e "${RED}Failed to stop containers in $SERVICE_NAME. Exiting.${NC}"
    exit 1
  fi

  # Create the backup zip
  timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
  zip_file="${SERVICE_NAME}_backup_${timestamp}.zip"
  echo "Creating backup for $SERVICE_NAME: $zip_file"
  zip -r "$zip_file" "${DIRECTORIES[@]}" || { 
    echo -e "${RED}Failed to zip directories for $SERVICE_NAME. Exiting.${NC}"
    exit 1
  }

  if [[ $BACKUP_TYPE -eq 1 ]]; then
    # Local-only backup
    echo "Moving $zip_file to local backup directory: $BACKUP_DIR"
    mv "$zip_file" "$BACKUP_DIR/" || {
      echo -e "${RED}Failed to move $zip_file to $BACKUP_DIR. Exiting.${NC}"
      exit 1
    }
  elif [[ $BACKUP_TYPE -eq 2 ]]; then
    # Rclone backup
    echo "Uploading $zip_file to $REMOTE_BACKUP_DIR/$SERVICE_NAME/"
    rclone copy -vv "$zip_file" "$REMOTE_BACKUP_DIR/$SERVICE_NAME/"

    # Check if the upload was successful
    if [[ $? -ne 0 ]]; then
      echo -e "${RED}Upload failed for $SERVICE_NAME. Moving backup to local storage.${NC}"
      mv "$zip_file" "$BACKUP_DIR/"
      UPLOAD_FAILURES=1
    else
      echo "Upload successful, removing $zip_file"
      rm "$zip_file"
    fi
  else
    echo -e "${RED}Invalid BACKUP_TYPE specified. Exiting.${NC}"
    exit 1
  fi

  # Restart the container for the service
  echo "Restarting containers in $SERVICE_NAME"
  cd "$MAIN_DIR" || { 
    echo -e "${RED}Failed to navigate to $MAIN_DIR. Exiting.${NC}"
    exit 1
  }
  docker compose start
}

# Process services with thread control
PIDS=()
CURRENT_THREADS=0
for SERVICE_ENTRY in "${SERVICES[@]}"; do
  process_service "$SERVICE_ENTRY" &
  PIDS+=("$!")
  CURRENT_THREADS=$((CURRENT_THREADS + 1))

  # Wait for threads to finish if limit is reached
  if [[ $CURRENT_THREADS -ge $MAX_THREADS ]]; then
    for PID in "${PIDS[@]}"; do
      wait "$PID"
    done
    PIDS=()
    CURRENT_THREADS=0
  fi
done

# Wait for any remaining background processes to complete
for PID in "${PIDS[@]}"; do
  wait "$PID"
done

# Check for upload failures and print a red alert if any occurred
if [[ $UPLOAD_FAILURES -ne 0 ]]; then
  echo -e "${RED}ALERT: One or more backups failed to upload. Check $BACKUP_DIR for local copies.${NC}"
else
  echo "All backups uploaded successfully."
fi

echo "Backup and restart process complete."

# Exit successfully
exit 0
