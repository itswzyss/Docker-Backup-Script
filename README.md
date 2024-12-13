# Backup Script

This script is designed to simplify the process of backing up multiple services. It supports both local backups and remote backups using `rclone`. The script allows for parallel backups and provides flexibility in configuration.

Note that this is only useful if you run everything in Docker with Docker Compose. This won't work at all if you do not use Docker Compose.

If you think there's a better way to do something or add support for X thing, feel free to submit a pull request.

## Features

- Backup multiple services / containers with specified directories.
- Support for local-only or remote (rclone) backups.
- Parallel processing with configurable thread limits.
- Customizable backup locations.
- Docker container management during the backup process. (Stops containers, zips them, then restarts containers)

## Requirements

- **Bash Shell**: Ensure the script runs on a system with a Bash-compatible shell.
- **Docker Compose**: Required for managing service containers.
- **Rclone** (optional): Needed for remote backups.
- **Zip**: Used for compressing backup files.
- **Ubuntu 24+**: Script was created with Ubuntu in mind. If you have bash, zip, and rclone installed, this should work on just about anything.

## Usage

### Configuration

1. **Set the Backup Type**:
   - `BACKUP_TYPE=1`: Local-only backup. Backups are stored in the `BACKUP_DIR`.
   - `BACKUP_TYPE=2`: Remote backup using `rclone`. Backups are uploaded to `REMOTE_BACKUP_DIR`.

2. **Configure Backup Directories**:
   - `BACKUP_DIR`: The local directory where backups are stored.
   - `REMOTE_BACKUP_DIR`: The remote directory used by `rclone` (only required if `BACKUP_TYPE=2`).

3. **Define Services**:
   - The `SERVICES` array lists all services and their directories. Each entry is formatted as:
     ```
     "service_name:/main/directory:/additional/directory1:/additional/directory2"
     ```
   - Example:
     ```
     SERVICES=(
       "authentik:/root/authentik:/var/lib/docker/volumes/authentik_database/_data"
       "statusnao:/root/statusnao"
     )
     ```

4. **Set Maximum Threads**:
   - `MAX_THREADS`: Controls the number of backup processes that run in parallel.

### Running the Script

1. Make the script executable:
   ```
   chmod +x backup.sh
   ```

2. Run the script:
   ```
   ./backup.sh
   ```

### Output

- Backup files are either moved to `BACKUP_DIR` (local) or uploaded to `REMOTE_BACKUP_DIR` (remote).
- Logs provide details about the backup process, including successes and failures.

## Error Handling

- If a backup fails, the script logs the error and moves the backup file to `BACKUP_DIR` for manual review.
- The script exits with an error message if critical issues occur, such as an invalid configuration.

## Customization

You can modify the script to include additional features or adapt it to your specific requirements. Ensure you validate any changes to prevent unexpected errors.

## License

This script is open-source and available under the MIT License. Feel free to use and modify it.

