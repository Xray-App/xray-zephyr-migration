# Zephyr → Xray Migration

This repository contains configuration files and scripts to migrate data from [Zephyr]() to [Xray](). The migration occurs at the database level, data are retrieved via the Jira and Zephyr APIs and written directly into the Xray database. The migration ELT (Extract-Load-Transform) process uses [Docker](https://docker.com) containers and data transformation scripts, to move data from Zephyr to Xray.

The migration copies the specified Zephyr projects from a Jira instance to the same or different Jira instance.

```mermaid
```

## Migration Requirements & Pre-requisites

> [!IMPORTANT]
> The TestRail instance that is the target of the data migration must use MySQL 8.x, not 5.x as the database.

1. The TestRail Server instance that is the target of the migration must be already setup and running.
1. macOS or Linux are recommended for the computer running the migration. The migration automation bash scripts in this repository configure and execute the Docker-based migration tooling, and require a [Unix-like](https://en.wikipedia.org/wiki/Unix-like) operating system that is capable of running bash scripts.

> [!TIP]
> [Windows PowerShell](https://learn.microsoft.com/en-us/powershell/) with [Windows Subsystem for Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/install) should suffice, if it is the only option, but it has not been tested.

3. Install [Git](https://git-scm.com/) on the computer running the migration.
1. Install [Docker](https://docs.docker.com/get-docker/) and docker-compose (which is included with [Docker Desktop](https://www.docker.com/products/docker-desktop/)) on the computer running the migration.
1. Allocate at least 16 gigabytes (GB) of RAM for running the Docker containers. The Docker default is 50% of the computer's RAM, so the default is sufficient on a computer with 32GB+ of RAM. You can adjust the amount of memory allocated to Docker from the [Docker Desktop settings](https://docs.docker.com/desktop/settings/mac/#advanced).

> [!IMPORTANT]
> The ALM Octane instance that is the source of the data migration must use SQL Server, not Oracle, as the database.

6. Verify that the computer running the migration has access to the MS SQL Server database of the ALM Octane instance that is the source of the migration. You will need:
  - the ALM Octane database host
  - the [Microsoft SQL Server](https://www.microsoft.com/sql-server) port (e.g. `1433`)
  - the name of the ALM Octane database (e.g. `default_shared_space`)
  - the ALM Octane database username (e.g. `sa`)
  - the password for the ALM Octane database user
7. Verify that the computer running the migration has access to the MySQL database of the TestRail instance that is the target of the migration. You will need:
  - the TestRail database host
  - the [MySQL](https://www.mysql.com/) port (e.g. `3306`)
  - the name of the TestRail database (e.g. `testrail`)
  - the TestRail database root username (e.g. `root`)
  - the password for the root TestRail database user 
8. Verify that the computer running the migration has access to the [Cassandra](https://cassandra.apache.org/_/index.html) database of the TestRail instance that is the target of the migration.
  - one or more Cassandra database hosts
  - the Cassandra port (e.g. `9042`)
  - the name of the keyspace used by TestRail (e.g. `tr_keyspace`)
  - a Cassandra database username (e.g. `cassandra`)
  - the password for the Cassandra database user
9. Ensure you have a spreadsheet application that is capable of viewing `.xlsx` files, such as MS Excel, Apple Numbers, Google Sheets, or LibreOffice.

### Attachment requirements

```mermaid
---
title: Attachment File Migration from ALM Octane to TestRail
---
block-beta
columns 5

odb[("\nALM Octane DB")]:1
space:3
trdb[("\nTestRail DB")]:1
space:5

os["ALM Octane\nAttachment Storage\nDirectory"]
space:1
block:migd["Docker\n\n\n"]
    columns 1
    space
    migrate["Migration Scripts"]
end
space:1
trs["TestRail\nAttachment Storage\nDirectory"]

odb -- "Attachment\nfile references" --> os
trdb -- "Attachment\nfile references" --> trs

odb -- "Attachment data" --> migrate
migrate -- "Attachment data" --> trdb

os -- "Copy from" --> migrate
migrate -- "Copy to" --> trs
```

You will need to provide two paths to attachment file storage locations, one for ALM Octane, where the current Octane attachment files are located, and one for TestRail, where the attachment files will be copied during the migration.

The ALM Octane attachment file storage location can be a mounted volume, or just a local copy of the Octane attachment storage.

During the migration process, the ALM Octane attachment files will be copied to the TestRail attachment storage location. If the TestRail attachment storage location is a mounted volume, then the attachment copy is complete after the migration. If not, the attachment directory can be copied to the TestRail instance attachment storage after the migration.

## Migration Usage

### Docker and GitHub repository preparation

1. Clone [this GitHub repository](https://github.com/gurock/tr-octane-migration) if you haven't already, with this command:

```console
git clone git@github.com:gurock/tr-octane-migration
```

2. Log in to GitHub, and from [settings](https://github.com/settings/tokens), click "Generate new token" and generate a (classic) personal access token (PAT). You must provide a token name, such as `TestRail migration`, an expiration, and the following scope:
  - `read:packages`

3. Click the green "Generate token" button.
1. Be sure to copy and save the personal access token once you've generated it.
1. Use the following command to log in to the [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) (GHCR) with your username and the PAT you just generated:

```console
export GHCR_PAT=<insert personal access token here>
export GHCR_USER=<insert GitHub username here>
echo $GHCR_PAT | docker login ghcr.io -u $GHCR_USER --password-stdin
```

6. Look for the `Login Succeeded` message. Now that you are logged in, you'll be able to pull the `tr-data-migration` image from GHCR, by following the steps in the next section.

### Container setup

1. Start the Docker container download and setup with the following commands:

```console
cd tr-octane-migration
./run.sh start
```

2. The script begins by pulling the `tr-data-migration` image from the [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) (GHCR).
1. At the prompt, enter the path for the ALM Octane attachments storage directory.
1. At the prompt, enter the path for the TestRail attachments storage directory.
1. The `tr-data-migration` image is then used to create two Docker containers, one running Airbyte, and the other running the migration data transformations. These Docker containers will be running in the background.
1. Three new directories will be created in your local copy of this repository:
- `/config` - Contains configuration files for ALM Octane and TestRail.
- `/logs` - Log files generated by the migrations you run will be stored here.
- `/reports` - Any migration reconciliation reports you generate will be stored here.
7. If any of these directories already exist, they won't be modified by the script.
1. Once you see the message `Airbyte containers are running!`, the setup script is complete.
By default, Airbyte will be running on port `8000`.
1. To check the status of the Airbyte and `tr-octane-migration` containers, run the following command:

```console
./run.sh status
```

10. Both containers should have a status of `running`. You are now ready to configure the migration.

### Migration configuration

Run the following command to configure settings for ALM Octane, TestRail, and Cassandra:

```console
./run.sh configure
```

> [!TIP]  
> If either the TestRail database or the ALM Octane database is running in a Docker container, you will need to use `host.docker.internal` in place of `localhost` or `127.0.0.1` in the configuration files.

Follow the steps below at each prompt to complete the configuration:

_ALM Octane_

1. Enter the URL of the ALM Octane database (`localhost` by default).
1. Enter the MSSQL port (`1433` by default).
1. Enter the name of the ALM Octane MSSQL database (`default_shared_space` by default).
1. Enter an ALM Octane database username (`sa` by default).
1. Enter the database user's password.

_TestRail_

1. Enter the URL of the TestRail database (`localhost` by default).
1. Enter the MySQL port (`3306` by default).
1. Enter the name of the TestRail MySQL database (`testrail` by default).
1. Enter the name of the root user for the TestRail MySQL database (`root` by default).
1. Enter the root user's password.

_Cassandra_

1. Enter one or more Cassandra host URLs, separated by commas (`localhost` by default).
1. Enter the Cassandra port (`9042` by default).
1. Enter the name of the keyspace being used by TestRail (`tr_keyspace` by default).
1. Enter a Cassandra database username (`cassandra` by default).
1. Enter the database user's password.

Once done, check the [TestRail config](./config/testrail/testrail-config.yml) and [ALM Octane config](./config/octane/octane-config.yml) files for the updated settings. You can modify these files directly to make any needed changes.

For an in-depth explanation of the settings within the configuration files, refer to the [configuration settings documentation](./Docs/configuration-settings.md).

Once you see the message, "Successfully set the global variable 'local_infile' to true", you are now ready to migrate the ALM Octane data with Airbyte.

### Airbyte migration (Extract-Load)

1. Run the following command to start the Airbyte migration:

```console
./run.sh airbyte
```

2. This script will extract data from the ALM Octane database and load it into newly created Airbyte tables in the TestRail database. These tables, all of which are prefixed with `_airbyte_raw_`, will later be used to migrate the data into TestRail tables.
1. For informational purposes, you can access the Airbyte UI at the URL and port specified in its configuration. The default URL is `localhost:8000`.
1. Once you see the message `✅ Job finished!` with a status of `succeeded`, the Airbyte migration is complete.

### ALM Octane migration scripts (Transform)

1. The data extracted from the ALM Octane database may contain multiple workspaces.
To choose which of these workspaces you want to migrate to TestRail projects, run the following command:

```console
./run.sh enumerate
```

2. This script will walk you through each ALM Octane workspace found in the Airbyte data, and prompt you to decide if you want to migrate them. To accept the currently specified workspace, press `y` for yes.
To skip the currently specified workspace, press `n` for no.
1. You can also accept the current specified workspace and all remaining workspaces by pressing `a` for all, or skip the currently specified workspace and all remaining workspaces by pressing `n` for none.
1. Once you've made your selections, the workspaces will be enumerated in `config/octane/octane-workspaces.yml`. You can further edit this file to make changes to the configuration.

5. To begin migrating the data corresponding to the workspaces enumerated in the previous step, run the following command:

```console
./run.sh migrate
```

6. Enter `migrate` at the prompt to confirm that you're ready to migrate the data to TestRail.
1. This will begin the migration process. Each migration script will run in sequence, and will output logs to both the console and to a log file in the `/logs` directory.
1. Once you see the message `ALM Octane migration complete!`, the migration is finished.

The full list of migration scripts are documented in in the [Octane migration scripts documentation](./Docs/octane-migration-scripts.md).

9. To migrate attachment files from ALM Octane to TestRail (e.g. image files, text files, etc.), run the following command:

```console
./run.sh migrate-attachments
```

10. Confirm that you're ready to migrate the attachment files by entering `migrate` at the prompt.
1. Once confirmed, the script will copy attachment files from the ALM Octane attachment storage location to the TestRail attachment storage location. The script will output logs to both the console and to a log file in the `/logs` directory.
1. You may see warnings about missing attachment files if they are not found, but the migration will continue without issue if the first copy attempt succeeds.
1. Once you see the message `ALM Octane attachment migration complete!`, the migration is finished.

### Reconciliation reporting

1. To generate a migration reconciliation report showing the data that was migrated from ALM Octane to TestRail (and the data that wasn't migrated), run the following command:

```console
./run.sh report
```

2. The script will output a spreadsheet in the `/reports` directory, showing the reconciliation of data between ALM Octane and TestRail. A command to open the report will be displayed in the console (e.g. `open ./reports/octane-report-2024-06-28T15:00:00Z.xlsx`). The command will open the report in your default spreadsheet application.

## Additional Information

### Cleaning migrated data

> [!WARNING]
> Cleaning migrated data means removing all the data that was copied to TestRail as a result of running the migration. Only perform this step if you want to "rollback" the migration and remove the migrated data.

1. After you've run the migration scripts, you may choose to remove the migrated data from the TestRail database. To do this, run the following command:

```console
./run.sh clean
```

2. Enter `clean` at the prompt to confirm that you're ready to remove the migrated data from TestRail.
1. Once confirmed, the script will remove the migrated data from the TestRail database. No data that already existed in TestRail separately from the migration will be removed. The script will output logs to both the console and to a log file in the `/logs` directory.

### Cleaning Airbyte data

> [!CAUTION]
> Cleaning Airbyte data means removing all the data that was extracted from ALM Octane and loaded into the TestRail database. This data contains a ledger record of the resulting transformation and migration of the data into the TestRail tables. If you remove the Airbyte data you will no longer be able to use this ledger record to clean the migrated data from TestRail in a migration "rollback".

1. Once you've cleaned the migrated data from TestRail, you may want to remove the Airbyte tables that were created during the Airbyte migration. To do this, run the following command:

```console
./run.sh clean-airbyte
```

2. Enter `clean` at the prompt to confirm that you're ready to remove the Airbyte tables from the TestRail database.
1. Once confirmed, the script will remove the Airbyte tables from the TestRail database. The script will output logs to both the console and to a log file in the `/logs` directory.

### Stopping the Docker containers

When you have completed the migration, you will want to stop the migration's Docker containers.

To bring down the Docker containers, run the following command:

```console
./run.sh stop
```

This will not remove the containers or their data.

### Removing the Docker containers

To remove the Docker containers and reset to the initial state, run the following:

```console
./run.sh reset
```

Enter `y` for yes at the prompt to confirm that you want to reset the container.

This command will stop and remove the container, and remove the following directories and their contents:
- `/config`
- `/logs`
- `/reports`

Then run:

```console
./run.sh reset-airbyte
```

Enter `y` for yes at the prompt to confirm that you want to reset the container.

This command will stop and remove the container.

### Additional commands

You can see a full list of available commands by running:

```bash
./run.sh help
```

Some seldom needed [additional commands](./Docs/additional-commands.md) are available.

In some rare circumstances, it may be helpful to [run individual data transformation jobs](./Docs/direct-launchers.md).