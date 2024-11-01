#!/usr/bin/env bash

# Welcome function, get a msg as parameter and print it in ascii art
Welcome() {
  # Echo TR Data Migration in ascii art
  cat <<'EOF'

____  ___                    
\   \/  /___________ ____ __ 
 \     /\_  __ \__  \\   |  |
 /     \ |  | \// __ \\___  |
/___/\  \|__|  (____  / ____|
      \_/           \/\/     
EOF
  echo $1
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
# OCTANE_ATTACHMENTS_FILE=./config/octane/attachments_path.txt
# TESTRAIL_ATTACHMENTS_FILE=./config/testrail/attachments_path.txt
# Xray and Zephyr Configuration
XRAY_ZEPHYR_MIGRATION_CONFIGURED=./config/xray/configured.txt

# Attachments paths

# # Collect the Octane attachments path from the user, default is ~/octane/repo/storage
# # save it in OCTANE_ATTACHMENTS_FILE
# CollectOctaneAttachmentsPath() {
#   # Ask the user for the path, check if it actually exists, if not repeat
#   while true; do
#     read -p "Enter the path to the Octane attachments (default is ~/octane/repo/storage): " octane_attachments_path
#     if [ -z "$octane_attachments_path" ]; then
#       octane_attachments_path="~/octane/repo/storage"
#     fi
#     octane_attachments_path=$(eval echo "$octane_attachments_path")
#     if [ -d "$octane_attachments_path" ]; then
#       break
#     else
#       echo "The path to the Octane attachments does not exist, please try again..."
#     fi
#   done
#   echo $octane_attachments_path > $OCTANE_ATTACHMENTS_FILE
# }

# # Collect the Octane attachments path if doesn't exists yet
# MaybeCollectOctaneAttachmentsPath() {
#   force_collect_attachments=$1
#   if [ ! -f $OCTANE_ATTACHMENTS_FILE ] || [ $force_collect_attachments -eq 1 ]; then
#     CollectOctaneAttachmentsPath
#   fi
# }

# # Collect the TestRail attachments path from the user, default is ~/testrail/_opt/attachments
# # save it in TESTRAIL_ATTACHMENTS_FILE
# CollectTestRailAttachmentsPath() {
#   # Ask the user for the path, check if it actually exists, if not repeat
#   while true; do
#     read -p "Enter the path to the TestRail attachments (default is ~/testrail/_opt/attachments): " testrail_attachments_path
#     if [ -z "$testrail_attachments_path" ]; then
#       testrail_attachments_path="~/testrail/_opt/attachments"
#     fi
#     testrail_attachments_path=$(eval echo "$testrail_attachments_path")
#     if [ -d "$testrail_attachments_path" ]; then
#       break
#     else
#       echo "The path to the TestRail attachments does not exist, please try again..."
#     fi
#   done
#   echo $testrail_attachments_path > $TESTRAIL_ATTACHMENTS_FILE
# }

# # Collect the TestRail attachments path if doesn't exists yet
# MaybeCollectTestRailAttachmentsPath() {
#   force_collect_attachments=$1
#   if [ ! -f $TESTRAIL_ATTACHMENTS_FILE ] || [ $force_collect_attachments -eq 1 ]; then
#     CollectTestRailAttachmentsPath
#   fi
# }

# Docker iamge and container handing

CreateImage() {
  # Pull the DOCKER_IMAGE image if not already present
  docker images | grep $DOCKER_IMAGE_TAG | grep $VERSION > /dev/null 2>&1
  if [ $? -ne 0 ]; then
      echo "Pulling the image..."
      docker pull $DOCKER_IMAGE
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
      # MaybeCollectOctaneAttachmentsPath $force_collect_attachments
      # MaybeCollectTestRailAttachmentsPath $force_collect_attachments
      # octane_attachments_path=$(cat $OCTANE_ATTACHMENTS_FILE)
      # testrail_attachments_path=$(cat $TESTRAIL_ATTACHMENTS_FILE)
      # echo "Now starting the container with Octane path $octane_attachments_path and TestRail path $testrail_attachments_path..."
      docker create -it --name $DOCKER_CONTAINER_NAME \
        -v $(pwd)/config/xray:/app/config/xray/ \
        -v $(pwd)/config/zephyr:/app/config/zephyr/ \
        -v $(pwd)/logs:/app/logs/ \
        -v $(pwd)/reports:/app/reports/ \
        $DOCKER_IMAGE
        # -v $(eval echo $octane_attachments_path):/app/octane/storage \
        # -v $(eval echo $testrail_attachments_path):/app/testrail/attachments \
  fi
}

StartContainer() {
  echo "Starting..."
  # Start the container
  docker start $DOCKER_CONTAINER_NAME
}

Start() {
  Welcome "Starting Xray Zephyr Migration..."
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
  Welcome "Stopping Xray Zephyr Migration..."
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
  Welcome "Resetting Xray Zephyr Migration..."
  # Prompt if the user is sure to reset, make sure they are going to delete the configs, logs and reports
  read -p "Are you sure you want to reset the Xray Zephyr Migration? (y/n) " -n 1 -r
  echo    # (optional) move to a new line
  if [[ ! $REPLY =~ ^[Yy]$ ]]
  then
    exit 1
  fi
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
    echo "Xray Zephyr Docker is not running, please start it first with './run.sh start' and then try again."
    exit 1
  fi
  # return an error if container is already configured, check using DidConfigure
  DidConfigure
  configured=$?
  if [ $configured -eq 1 ]; then
    echo "Xray Zephyr Docker is already configured, to re-configure it use './run.sh configure'."
    exit 1
  fi
  # configure the container
  docker exec -it -e FILE_LOG_LEVEL=OFF $DOCKER_CONTAINER_NAME bin/collect-info zephyr
  CopySSHKeys
  # Touch $XRAY_ZEPHYR_MIGRATION_CONFIGURED unless previous command failed
  if [ $? -ne 0 ]; then
    echo "Failed to configure Xray Zephyr Docker, please try again."
    exit 1
  else
    echo "Excellent, your Xray Zephyr Docker is now configured!"
  fi
  touch $XRAY_ZEPHYR_MIGRATION_CONFIGURED
}

ConfigureAttachmentsPaths() {
  Welcome "Configuring Zephyr and Xray attachments paths..."
  # return an error if container is not running
  ContainerDidStart
  containerStarted=$?
  if [ $containerStarted -ne 0 ]; then
    echo "Xray Zephyr Docker is not running, please start it first with './run.sh start' and then try again."
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
    echo "Xray Zephyr Docker: unknown"
  elif echo "$docker_ps" | grep -q "Exited"; then
    echo "Xray Zephyr Docker: stopped"
  else
    echo "Xray Zephyr Docker: running"
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
    echo "Xray Zephyr Docker didn't start yet, please start them first with './run.sh start' and then try again."
    exit 1
  fi

  # return an error if $DOCKER_CONTAINER_NAME container is not configured
  DidConfigure
  configured=$?
  if [ $configured -ne 1 ]; then
    echo "Xray Zephyr Docker is not configured, please configure it first with './run.sh configure' and then try again."
    exit 1
  fi
}

# SSH

CopySSHKeys() {
  keys_line=$(cat ./config/xray/xray-config.yml | grep "  keys:")
  keys=$(echo "$keys_line" | grep -o '"[^"]*"' | tr -d '"' | sed "s|~|$HOME|g")

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

Retrieve() {
  Welcome "Retrieving Xray Data Migration..."
  CanGo
  docker exec -it $DOCKER_CONTAINER_NAME zephyr/retrieve_projects
}

Migrate() {
  Welcome "Migrating TR Data Migration..."
  CanGo
  docker exec -it $DOCKER_CONTAINER_NAME zephyr/migrate_projects
}

# Report

Report() {
  Welcome "Generating reconciliation report..."
  CanGo
  docker exec -it $DOCKER_CONTAINER_NAME util/run_report zephyr
}

# Clean

CleanMigration() {
  Welcome "Cleaning TR Data Migration..."
  docker exec -it $DOCKER_CONTAINER_NAME zephyr/clean_migration
}

CleanRest() {
  Welcome "Cleaning retrieved tables..."
  docker exec -it $DOCKER_CONTAINER_NAME util/clean_rest_tables
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
  echo "Xray Data Migration setup complete! Now you can retrieve the data with './run.sh retrieve' and then migrate them with './run.sh migrate'. See './run.sh help' for more information."
}

# Help

Help() {
  Welcome
  echo -e "Usage: $0 start|stop|status|reset|configure|status|enumerate|migrate|migrate-attachments|clean|clean-rest"
  echo -e ""
  echo -e "* go"
  echo -e "  One shot start and setup\n"
  echo -e "* start"
  echo -e "  Start xray-zephyr-migration container\n"
  echo -e "* stop"
  echo -e "  Stop xray-zephyr-migration container\n"
  echo -e "* status"
  echo -e "  Show the status of the xray-zephyr-migration container\n"
  echo -e "* configure"
  echo -e "  Collect the Zephyr and Xray configuration\n"
  echo -e "* configure-attachments"
  echo -e "  Set the attachments path for both Zephyr and Xray\n"
  echo -e "* migrate"
  echo -e "  Migrate the projects\n"
  echo -e "* migrate-attachments"
  echo -e "  Migrate the attachments\n"
  echo -e "* report"
  echo -e "  Generate the reconciliation report\n"
  echo -e "* clean"
  echo -e "  Clean the migration\n"
  echo -e "* clean-rest"
  echo -e "  Clean retrieved tables\n"
  echo -e "* reset"
  echo -e "  Reset the Xray Data Migration\n"
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
    Welcome "Configuring Xray Data Migration..."
    rm -f "$XRAY_ZEPHYR_MIGRATION_CONFIGURED"
    Configure
  elif [ "$1" == "configure-attachments" ]; then
    ConfigureAttachmentsPaths
  elif [ "$1" == "status" ]; then
    Status
  elif [ "$1" == "retrieve" ]; then
    Retrieve
  elif [ "$1" == "migrate" ]; then
    Migrate
  elif [ "$1" == "report" ]; then
    Report
  elif [ "$1" == "clean" ]; then
    CleanMigration
  elif [ "$1" == "clean-rest" ]; then
    CleanRest
  elif [ "$1" == "reset" ]; then
    Reset
  elif [ "$1" == "help" ]; then
    Help
  elif [ "$1" == "copy-ssh-keys" ]; then
    CopySSHKeys
  else
    echo "Unknown command: $1"
  fi
}

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