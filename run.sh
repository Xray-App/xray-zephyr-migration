#!/usr/bin/env bash

# Welcome function, get a msg as parameter and print it in ascii art
Welcome() {
  # Echo Xray Migration ASCII art
  cat <<'EOF'

____  ___                    
\   \/  /___________ ____ __ 
 \     /\_  __ \__  \\   |  |
 /     \ |  | \// __ \\___  |
/___/\  \|__|  (____  / ____|
      \_/           \/\/     

Zephyr Scale to Xray Migration

EOF
  echo $1
  echo ""
  sleep 1
}
# Docker image
VERSION=latest
GH_ACTOR=xray-app
DOCKER_IMAGE_NAME=xray-data-migration
DOCKER_CONTAINER_NAME=xray-zephyr-migration
DOCKER_TEMP_CONTAINER_NAME=$DOCKER_CONTAINER_NAME-temp
DOCKER_IMAGE_TAG=ghcr.io/$GH_ACTOR/$DOCKER_IMAGE_NAME
DOCKER_IMAGE=$DOCKER_IMAGE_TAG:$VERSION
# Attachments
ATTACHMENTS_METHOD_FILE=$PWD/attachments_method.txt
XRAY_ATTACHMENTS_FILE=./config/xray/attachments_path.txt
# Xray and Zephyr Configuration
XRAY_ZEPHYR_MIGRATION_CONFIGURED=./config/xray/configured.txt
MIN_DOCKER_ENGINE_VERSION=24.0.2

# Attachments paths

AskForAttachmentsMethod() {
  echo # Move to a new line
  echo "You can choose to copy migrated attachments remotely to the target Jira/Xray instance using SFTP, or you can just copy them locally if this migration is running on the target Jira/Xray instance, or if you have a network mount available."
  read -p "Will you be using SFTP to copy migrated attachments remotely to the target Jira/Xray instance machine? (y/n) " -n 1 -r
  echo # Move to a new line
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo 'local' > $ATTACHMENTS_METHOD_FILE
  else
    echo 'sftp' > $ATTACHMENTS_METHOD_FILE
  fi
}

# Collect the Xray attachments path from the user, default is $PWD/attachments_storage
# save it in XRAY_ATTACHMENTS_FILE
CollectXrayAttachmentsPath() {
  # Ask the user for the path, check if it actually exists, if not repeat
  while true; do
    read -p "Enter the path to the Xray attachments storage location (default is $PWD/attachments_storage): " xray_attachments_path
    if [ -z "$xray_attachments_path" ]; then
      xray_attachments_path="$PWD/attachments_storage"
    fi
    xray_attachments_path=$(eval echo "$xray_attachments_path")
    if [ -d "$xray_attachments_path" ]; then
      break
    else
      read -p "The path to the Xray attachments does not exist, would you like to create it? (y/n)" -n 1 -r
      echo # Move to a new line
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting..."
        exit 1
      fi
      mkdir -p $xray_attachments_path
      break
    fi
  done
  echo $xray_attachments_path > $XRAY_ATTACHMENTS_FILE
}

# Collect the Xray attachments path if doesn't exists yet
MaybeCollectXrayAttachmentsPath() {
  force_collect_attachments=$1
  if [ ! -f $XRAY_ATTACHMENTS_FILE ] || [ $force_collect_attachments -eq 1 ]; then
    CollectXrayAttachmentsPath
  fi
}

CheckDockerEngineVersion() {
  # Check if Docker is installed and running
  if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
  fi

  # Check if Docker daemon is running
  if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running"
    exit 1
  fi

  # Get current Docker Engine version
  current_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
  if [ -z "$current_version" ]; then
    echo "Error: Could not determine Docker Engine version"
    exit 1
  fi

  # Extract version numbers for comparison (remove any build metadata)
  current_version_clean=$(echo "$current_version" | cut -d'-' -f1)
  min_version_clean=$(echo "$MIN_DOCKER_ENGINE_VERSION" | cut -d'-' -f1)

  # Compare versions using sort -V (version sort)
  if [ "$(printf '%s\n' "$current_version_clean" "$min_version_clean" | sort -V | head -n1)" != "$min_version_clean" ]; then
    echo "Error: Docker Engine version $current_version is lower than required minimum version $MIN_DOCKER_ENGINE_VERSION"
    echo "Please upgrade Docker Engine to version $MIN_DOCKER_ENGINE_VERSION or higher"
    exit 1
  fi
}
# Docker iamge and container handing

CreateImage() {
  # Pull the DOCKER_IMAGE image if not already present
  docker images | grep $DOCKER_IMAGE_TAG | grep $VERSION > /dev/null 2>&1
  if [ $? -ne 0 ]; then
      echo "Pulling the image..."
      if ! docker pull $DOCKER_IMAGE; then
        echo "Failed to pull the image, make sure you logged in via 'docker login ghcr.io', that your user is part of the '$GH_ACTOR' organization on GitHub and that the PAT you are using has the read:packages scope."
        exit 1
      fi
  fi

  # If /config/xray or /config/zephyr don't exists, copy them from the docker volume
  if [ ! -d "./config/xray" ] || [ ! -d "./config/zephyr" ] || [ ! -d "./logs" ] || [ ! -d "./reports" ]; then
    # Run the container in detached mode
    echo "Starting the container temporarily so we can copy the shared folders..."
    docker run -d --name $DOCKER_TEMP_CONTAINER_NAME $DOCKER_IMAGE > /dev/null 2>&1
    # Copy the shared folders
    if [ ! -d "./config/xray" ]; then
      echo "Copying /app/config/xray"
      mkdir -p ./config
      docker cp $DOCKER_TEMP_CONTAINER_NAME:/app/config/xray ./config
    fi
    if [ ! -d "./config/zephyr" ]; then
      echo "Copying /app/config/zephyr"
      mkdir -p ./config
      docker cp $DOCKER_TEMP_CONTAINER_NAME:/app/config/zephyr ./config
    fi
    if [ ! -d "./logs" ]; then
      echo "Copying /app/logs"
      docker cp $DOCKER_TEMP_CONTAINER_NAME:/app/logs ./
    fi
    if [ ! -d "./reports" ]; then
      echo "Copying /app/reports"
      docker cp $DOCKER_TEMP_CONTAINER_NAME:/app/reports ./
    fi
    if [ ! -d "./source_attachments" ]; then
      echo "Creating ./source_attachments folder if it does not exist"
      mkdir -p ./source_attachments
    fi
    # Stop the container
    echo "Stopping the temporary container..."
    docker stop $DOCKER_TEMP_CONTAINER_NAME
    # Remove the container
    echo "Removing the container..."
    docker container rm $DOCKER_TEMP_CONTAINER_NAME
  fi
}

CreateContainer() {
  force_collect_attachments=$1
  # Create the xray-zephyr-docker container if not already present
  docker ps -a | grep $DOCKER_CONTAINER_NAME > /dev/null 2>&1
  if [ $? -ne 0 ]; then
      echo "Creating the container with the mounted volumes..."
      AskForAttachmentsMethod
      attachments_method=$(cat $ATTACHMENTS_METHOD_FILE)
      if [ $attachments_method = 'local' ]; then
        MaybeCollectXrayAttachmentsPath $force_collect_attachments
        xray_attachments_path=$(cat $XRAY_ATTACHMENTS_FILE)
      else
        xray_attachments_path="$PWD/source_attachments"
      fi
      echo "Now starting the container with the Xray attachments path $xray_attachments_path..."
      docker create -it --name $DOCKER_CONTAINER_NAME \
        -v $(pwd)/config/xray:/app/config/xray/ \
        -v $(pwd)/config/zephyr:/app/config/zephyr/ \
        -v $(pwd)/logs:/app/logs/ \
        -v $(pwd)/reports:/app/reports/ \
        -v $(eval echo $xray_attachments_path):/app/attachments_storage \
        -v $(eval echo $PWD/source_attachments):/app/source_attachments \
        $DOCKER_IMAGE
  fi
}

StartContainer() {
  echo "Starting..."
  # Start the container
  docker start $DOCKER_CONTAINER_NAME
}

Start() {
  Welcome "Starting the Zephyr Scale to Xray migration..."
  ## Zephyr docker
  CreateImage
  CreateContainer
  StartContainer
}

StopContainer() {
  # Stop the container
  docker stop $DOCKER_CONTAINER_NAME
}

Stop() {
  Welcome "Stopping the Zephyr Scale to Xray Migration..."
  StopContainer
}

# Reset

StopAndRemoveTempContainer() {
  echo "Stopping the temporary Docker container..."
  # Stopping the temporary container
  docker stop $DOCKER_TEMP_CONTAINER_NAME
  echo "Removing the temporary Docker container..."
  # Remove the temporary container, just in case the installation failed
  docker container rm $DOCKER_TEMP_CONTAINER_NAME
}

StopAndRemoveContainer() {
  StopAndRemoveTempContainer
  echo "Stopping the Docker container..."
  StopContainer
  # Remove the container
  echo "Removing the Docker container..."
  docker container rm $DOCKER_CONTAINER_NAME
}

Reset() {
  Welcome "Resetting the Zephyr Scale to Xray migration..."
  # Prompt if the user is sure to reset, make sure they are going to delete the configs, logs and reports
  read -p "Are you sure you want to reset the migration? (y/n) " -n 1 -r
  echo    # (optional) move to a new line
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
    exit 1
  fi
  echo "Removing $ATTACHMENTS_METHOD_FILE"
  rm -f $ATTACHMENTS_METHOD_FILE
  echo "Removing $XRAY_ZEPHYR_MIGRATION_CONFIGURED"
  rm -f $XRAY_ZEPHYR_MIGRATION_CONFIGURED
  StopAndRemoveContainer
  # Remove the image
  echo "Removing the Docker image..."
  docker image rm $DOCKER_IMAGE
  # Remove the volumes
  echo "Removing the volumes..."
  if [ -d "./logs" ]; then
    rm -rf ./logs
  fi
  if [ -d "./config" ]; then
    rm -rf ./config
  fi
  if [ -d "./reports" ]; then
    rm -rf ./reports
  fi
}

# Configure

Configure() {
  # return an error if container is not running
  ContainerDidStart
  containerStarted=$?
  if [ $containerStarted -ne 0 ]; then
    echo "The Docker container is not running, please start it first with './run.sh start' and then try again."
    exit 1
  fi
  # return an error if container is already configured, check using DidConfigure
  DidConfigure
  configured=$?
  if [ $configured -eq 1 ]; then
    echo "The Docker container is already configured, to re-configure it use './run.sh configure'."
    exit 1
  fi
  # configure the container
  docker exec -it -e FILE_LOG_LEVEL=OFF $DOCKER_CONTAINER_NAME bin/collect-info zephyr $(cat $ATTACHMENTS_METHOD_FILE)
  MaybeCopySSHKeys
  # Touch $XRAY_ZEPHYR_MIGRATION_CONFIGURED unless previous command failed
  if [ $? -ne 0 ]; then
    echo "Failed to configure the Docker container, please try again."
    exit 1
  else
    echo "Excellent, your Docker container is now configured!"
  fi
  touch $XRAY_ZEPHYR_MIGRATION_CONFIGURED
}

ConfigureAttachmentsPaths() {
  Welcome "Configuring Xray attachments paths..."
  # return an error if container is not running
  ContainerDidStart
  containerStarted=$?
  if [ $containerStarted -ne 0 ]; then
    echo "The Docker container is not running, please start it first with './run.sh start' and then try again."
    exit 1
  fi
  StopAndRemoveContainer
  CreateImage
  CreateContainer 1
  StartContainer
}

# Status check and handling

Status() {
  # Check if the docker image exists
  docker_ps=$(docker ps -a | grep $DOCKER_CONTAINER_NAME)
  if [ -z "$docker_ps" ]; then
    echo "Migration Docker container: unknown"
  elif echo "$docker_ps" | grep -q "Exited"; then
    echo "Migration Docker container: stopped"
  else
    echo "Migration Docker container: running"
  fi
}

ContainerDidStart() {
  # Return 1 if $DOCKER_CONTAINER_NAME container is running
  docker ps -a | grep $DOCKER_CONTAINER_NAME > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    return 1
  else
    return 0
  fi
}

DidConfigure() {
  # Return 1 if $DOCKER_CONTAINER_NAME container is configured
  if [ -f "$XRAY_ZEPHYR_MIGRATION_CONFIGURED" ]; then
    return 1
  else
    return 0
  fi
}

CanGo() {
  # if $DOCKER_CONTAINER_NAME didn't start yet, exit with an error
  ContainerDidStart
  containerStarted=$?
  if [ $containerStarted -ne 0 ]; then
    echo "The Docker container didn't start yet, please start it first with './run.sh start' and then try again."
    exit 1
  fi

  # return an error if $DOCKER_CONTAINER_NAME container is not configured
  DidConfigure
  configured=$?
  if [ $configured -ne 1 ]; then
    echo "The Docker container is not configured, please configure it first with './run.sh configure' and then try again."
    exit 1
  fi
}

# SSH

MaybeCopySSHKeys() {
  keys_line=$(cat ./config/xray/xray-config.yml | grep "^\s*keys:")
  # Get the keys values only if keys_line is not empty
  if [ -n "$keys_line" ]; then
    keys=$(echo "$keys_line" | grep -o '"[^"]*"' | tr -d '"' | sed "s|~|$HOME|g")

    CopySSHKeys $keys
  fi
}

CopySSHKeys() {
  keys=$1
  docker exec $DOCKER_CONTAINER_NAME mkdir -p /root/.ssh
  docker exec $DOCKER_CONTAINER_NAME chmod 700 /root/.ssh

  # Loop through each key path
  for key_path in $keys; do
    # Get just the filename
    dir_name=$(dirname "$key_path")
    key_name=$(basename "$key_path")
    
    # If the file exists on host, copy its content
    if [ -f "$key_path" ]; then
      # Copy content and set correct permissions
      docker cp $key_path $DOCKER_CONTAINER_NAME:/root/.ssh/$key_name
      docker exec $DOCKER_CONTAINER_NAME chmod 600 /root/.ssh/$key_name
    else
      echo "Warning: $key_path not found"
    fi
  done
}

# Migration handling

EnvVars() {
  # Get the env vars from the .env file
  echo "-e ZEPHYR_REST_TIMEOUT=$ZEPHYR_BASE_URL -e ZEPHYR_REST_OPEN_TIMEOUT=$ZEPHYR_REST_OPEN_TIMEOUT -e TERMINAL_LOG_LEVEL=$TERMINAL_LOG_LEVEL -e FILE_LOG_LEVEL=$FILE_LOG_LEVEL"
}

Extract() {
  echo "DBG: $(EnvVars)"
  Welcome "Extracting the Zephyr Scale projects..."
  CanGo
  docker exec -it $(EnvVars) $DOCKER_CONTAINER_NAME zephyr/extract_projects
}

DryExtract() {
  Welcome "Extracting the Zephyr Scale projects (dry run)..."
  CanGo
  docker exec -it $(EnvVars) $DOCKER_CONTAINER_NAME zephyr/extract_projects --dry
}

Migrate() {
  Welcome "Migrating the Zephyr Scale projects to Xray..."
  CanGo
  docker exec -it $(EnvVars) $DOCKER_CONTAINER_NAME zephyr/migrate_projects
}

MigrateOnlyAttachments() {
  Welcome "Migrating the Zephyr Scale attachments to Xray..."
  CanGo
  docker exec -it $(EnvVars) $DOCKER_CONTAINER_NAME zephyr/migrate_projects --only-attachments
}

MigrateSkipAttachments() {
  Welcome "Migrating the Zephyr Scale projects without attachments to Xray..."
  CanGo
  docker exec -it $(EnvVars) $DOCKER_CONTAINER_NAME zephyr/migrate_projects --skip-attachments
}

DryMigrate() {
  Welcome "Migrating the Zephyr Scale projects to Xray (dry run)..."
  CanGo
  docker exec -it $(EnvVars) $DOCKER_CONTAINER_NAME zephyr/migrate_projects --dry
}

# Report

Report() {
  Welcome "Generating the migration reconciliation report..."
  CanGo
  docker exec -it $(EnvVars) $DOCKER_CONTAINER_NAME util/run_report zephyr
}

# Clean

CleanMigration() {
  Welcome "Cleaning migrated data..."
  docker exec -it $(EnvVars) $DOCKER_CONTAINER_NAME zephyr/clean_migration
}

CleanRest() {
  Welcome "Cleaning extracted Zephyr Scale data..."
  docker exec -it $(EnvVars) $DOCKER_CONTAINER_NAME util/clean_rest_tables
}


# Go

Go() {
  ContainerDidStart
  containerStarted=$?
  if [ $containerStarted -ne 0 ]; then
    Start
  fi
  DidConfigure
  configured=$?
  if [ $configured -ne 1 ]; then
    Configure
  fi
  echo "The Zephyr Scale to Xray migration setup is complete! Now you can extract the Zephyr Scale data with './run.sh extract' and then migrate it to Xray with './run.sh migrate'. See './run.sh help' for more information."
}

# Help

Help() {
  Welcome
  echo -e "Usage: $0 start|stop|status|reset|configure|status|enumerate|migrate|migrate-only-attachments|migrate-skip-attachments|clean|clean-extracted-data"
  echo -e ""
  echo -e "* go"
  echo -e "  One shot start and setup\n"
  echo -e "* start"
  echo -e "  Start the xray-zephyr-migration container\n"
  echo -e "* stop"
  echo -e "  Stop the xray-zephyr-migration container\n"
  echo -e "* status"
  echo -e "  Show the status of the xray-zephyr-migration container\n"
  echo -e "* configure"
  echo -e "  Setup the Zephyr Scale and Xray configuration\n"
  echo -e "* configure-attachments"
  echo -e "  Set the attachments path for Zephyr Scale and Xray\n"
  echo -e "* extract"
  echo -e "  Create the project tables necessary for the migration to Xray\n"
  echo -e "* migrate"
  echo -e "  Migrate the projects\n"
  echo -e "* migrate-only-attachments"
  echo -e "  Migrate only the attachments\n"
  echo -e "* migrate-skip-attachments"
  echo -e "  Migrate the projects without attachments\n"
  echo -e "* report"
  echo -e "  Generate the reconciliation report\n"
  echo -e "* clean"
  echo -e "  Clean the migration\n"
  echo -e "* clean-extracted-data"
  echo -e "  Clean extracted Zephyr Scale data\n"
  echo -e "* reset"
  echo -e "  Reset the Zephyr Scale to Xray migration\n"
}

# Run

Run() {
  # Invoke the function based on the specified command
  if [ "$1" == "start" ]; then
    Start
  elif [ "$1" == "go" ]; then
    Go
  elif [ "$1" == "stop" ]; then
    Stop
  elif [ "$1" == "configure" ]; then
    Welcome "Configuring the Zephyr Scale to Xray migration..."
    rm -f "$XRAY_ZEPHYR_MIGRATION_CONFIGURED"
    Configure
  elif [ "$1" == "configure-attachments" ]; then
    ConfigureAttachmentsPaths
  elif [ "$1" == "status" ]; then
    Status
  elif [ "$1" == "extract" ]; then
    Extract
  elif [ "$1" == "dry-extract" ]; then
    DryExtract
  elif [ "$1" == "migrate" ]; then
    Migrate
  elif [ "$1" == "migrate-only-attachments" ]; then
    MigrateOnlyAttachments
  elif [ "$1" == "migrate-skip-attachments" ]; then
    MigrateSkipAttachments
  elif [ "$1" == "dry-migrate" ]; then
    DryMigrate
  elif [ "$1" == "report" ]; then
    Report
  elif [ "$1" == "clean" ]; then
    CleanMigration
  elif [ "$1" == "clean-extracted-data" ]; then
    CleanRest
  elif [ "$1" == "reset" ]; then
    Reset
  elif [ "$1" == "help" ]; then
    Help
  elif [ "$1" == "copy-ssh-keys" ]; then
    MaybeCopySSHKeys
  else
    echo "Unknown command: $1"
  fi
}

# Always check the docker engine version
CheckDockerEngineVersion

# If no start parameter was specified, print the help and ask for the command
if [ -z "$1" ]; then
  Help
  # Ask the user for the command or press Enter to start
  read -p "Enter the command or press Enter to go: " command
  if [ -z "$command" ]; then
    Go
  else
    Run $command
  fi
else
  Run $1
fi