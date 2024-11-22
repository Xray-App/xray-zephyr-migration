# Zephyr Scale → Xray Migration

This repository contains configuration files and scripts to migrate data from SmartBear's [Zephyr Scale](https://smartbear.com/test-management/zephyr-scale/) to [Xray](https://www.getxray.app/). The migration retrieves data via the Jira and Zephyr Scale APIs, then writes directly to the Jira and Xray database. The migration ELT (Extract-Load-Transform) process uses [Docker](https://docker.com) containers and data transformation scripts, to move data from Zephyr Scale to Xray.

The migration copies the specified Zephyr Scale projects from a Jira instance to Xray projects on either the same or a different Jira instance.

```mermaid
---
title: Data Migration from Zephyr Scale to Xray
---
block-beta
columns 6
%% First row
zdb[("\nZephyr DB")]:1
zjdb[("\nJira DB")]:1
space:2
block:migd["Docker\n\n\n"]
    columns 1
    space
    migrate["Migration Scripts"]
end
space
%% Second row
space:6
%% Third row
zapi["Zephyr API"]:1
space
block:apd[("Docker\n\n\n")]
    columns 1
    space
    ap["Extraction Scripts"]
end
space
xdb[("\nXray DB")]:1
space
%% Fourth row
space:5
xjdb[("\nJira DB")]:1
zapi --> zdb
zapi --> zjdb
zapi -- "Extract" --> ap
ap -- "Load" --> xdb
ap -- "Load" --> xjdb
migrate --> xdb
xdb -- "Transform" --> migrate
xjdb -- "Transform" --> migrate
```

## Migration Process

There are 3 primary factors when considering migrating data from Zephyr Scale to Xray.

1. Is the source and the target on the same Jira instance, or a different instance?
2. Does the target project already exist in Jira, or is it a new project?
3. If it is an existing project, is the target project already an Xray project?

This means there are 6 possible cases, as seen in this table.

|                | New Target Project                | non-Xray Target Project                   | Existing Xray Target Project                           |
|:---------------|:----------------------------------|:------------------------------------------|:-------------------------------------------------------|
| Same Jira      | new Xray project / same Jira      | convert non-Xray project / same Jira      | migrate data to existing Xray project / same Jira      |
| Different Jira | new Xray project / different Jira | convert non-Xray project / different Jira | migrate data to existing Xray project / different Jira |

<img src="https://github.com/xray-app/xray-zephyr-migration/raw/main/assets/Zephyr-Scale-to-Xray-Migration-with-Different-Jira-Instances.drawio.png" alt="Migration with different Jira instances"/>

### Single Jira Instance Migration

There is also a simpler case for migrating between Zephyr Scale and Xray on the same Jira instance.

<img src="https://github.com/xray-app/xray-zephyr-migration/raw/main/assets/Zephyr-Scale-to-Xray-Migration-within-the-same-Jira-Instance.drawio.png" alt="Migration within the same Jira instance" width="600"/>

### Zephyr Scale → Xray Entities Mapping

The table below illustrates the mappings between Zephyr Scale and Xray.

| Zephyr                  | Xray            | Notes                                                                                      |
|:------------------------|:----------------|:-------------------------------------------------------------------------------------------|
| Project                 | Project         |                                                                                            |
| User                    | User            |                                                                                            |
|                         |                 |                                                                                            |
| CUSTOM FIELDS           |                 |                                                                                            |
| Test Case Custom Field  | Custom Field    |                                                                                            |
| Test Plan Custom Field  | Custom Field    |                                                                                            |
| Test Cycle Custom Field | Custom Field    |                                                                                            |
|                         |                 |                                                                                            |
| ENTITIES                |                 |                                                                                            |
| Test Case               | Jira Issue      |                                                                                            |
| Test Cycle              | Jira Issue      |                                                                                            |
| Test Run                | Test Run        | The destination table is (project key)_`TEST_RUN` (e.g. `AO_ABC123_TEST_RUN`) in Xray.     |
| Test Plan               | Jira Issue      |                                                                                            |
|                         |                 |                                                                                            |
| ATTACHMENTS             |                 |                                                                                            |
| Test Case Attachments   | File Attachment |                                                                                            |
| Test Cycle Attachments  | File Attachment |                                                                                            |
| Test Run Attachments    | Attachment      | The destination table is (project key)_`ATTACHMENT` (e.g. `AO_ABC123_ATTACHMENT`) in Xray. |
| Test Plan Attachments   | File Attachment |                                                                                            |

## Migration Requirements & Pre-requisites

1. The Jira instance(s) that are the source and the target of the migration must be already setup and running.
1. macOS or Linux are recommended for the computer running the migration. The migration automation bash scripts in this repository configure and execute the Docker-based migration tooling, and require a [Unix-like](https://en.wikipedia.org/wiki/Unix-like) operating system that is capable of running bash scripts.

> [!TIP]
> [Windows PowerShell](https://learn.microsoft.com/en-us/powershell/) with [Windows Subsystem for Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/install) should suffice, if it is the only option, but it has not been tested.

3. Install [Git](https://git-scm.com/) on the computer running the migration.
1. Install [Docker](https://docs.docker.com/get-docker/) and docker-compose (which is included with [Docker Desktop](https://www.docker.com/products/docker-desktop/)) on the computer running the migration.
1. Allocate at least 16 gigabytes (GB) of RAM for running the Docker containers. The Docker default is 50% of the computer's RAM, so the default is sufficient on a computer with 32GB+ of RAM. You can adjust the amount of memory allocated to Docker from the [Docker Desktop settings](https://docs.docker.com/desktop/settings/mac/#advanced).

6. Verify that the computer running the migration has access to the Postgres database of the Jira instance that is the target of the migration. You will need:
  - the Jira database host
  - the [Postgres](https://www.postgresql.org/) port (e.g. `5432`)
  - the name of the Jira database (e.g. `jiradb`)
  - the Jira database username (e.g. `jira_user`)
  - the password for the Jira database user
7. Ensure you have a spreadsheet application that is capable of viewing `.xlsx` files, such as MS Excel, Apple Numbers, Google Sheets, or LibreOffice.

### Attachment requirements

```mermaid
---
title: Attachment File Migration from Zephyr Scale to Xray
---
block-beta
columns 5
%% First row
space:4
xdb[("\nXray DB")]:1
%% Second row
space:5
%% Third row
zapi["Zephyr API"]:1
space

block:migd["Docker\n\n\n"]
    columns 1
    space
    migrate["Migration Scripts"]
end
space:1
xs["Xray\nAttachment Storage\nDirectory"]

xdb -- "Attachment\nfile references" --> xs

migrate -- "Attachment data" --> xdb

zapi -- "Attachment data\nCopy from" --> migrate
migrate -- "Copy to" --> xs
```

You will need to provide the path to the Xray attachment file storage location, where attachment files will be copied during the migration.

You can choose to copy migrated attachments remotely to the target Xray instance using SSH File Transfer Protocol (SFTP), or you can just copy them locally if this migration is running on the target Xray instance, or if you have a network mount available.

During the migration process, the Zephyr Scale attachment files will be copied to the Xray attachment storage location.

## Migration Usage

### Docker and GitHub repository preparation

1. Clone [this GitHub repository](https://github.com/Xray-App/xray-zephyr-migration) if you haven't already, with this command:

```console
git clone git@github.com:xray-app/xray-zephyr-migration
```

2. Log in to GitHub, and from [settings](https://github.com/settings/tokens), click "Generate new token" and generate a (classic) personal access token (PAT). You must provide a token name, such as `Xray migration`, an expiration, and the following scope:
  - `read:packages`

3. Click the green "Generate token" button.
1. Be sure to copy and save the personal access token once you've generated it.
1. Use the following command to log in to the [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) (GHCR) with your username and the PAT you just generated:

```console
export GHCR_PAT=<insert personal access token here>
export GHCR_USER=<insert GitHub username here>
echo $GHCR_PAT | docker login ghcr.io -u $GHCR_USER --password-stdin
```

6. Look for the `Login Succeeded` message. Now that you are logged in, you'll be able to pull the `xray-zephyr-migration` image from GHCR, by following the steps in the next section.

### Container setup

1. Start the Docker container download and setup with the following commands:

```console
cd xray-zephyr-migration
./run.sh start
```

2. The script begins by pulling the `xray-zephyr-migration` image from the [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) (GHCR).
1. After the image is pulled, you should see the following message:

```console
You can choose to copy migrated attachments remotely to the target Jira/Xray instance using SSH File Transfer Protocol (SFTP), or you can just copy them locally if this migration is running on the target Jira/Xray instance, or if you have a network mount available.
```

and the following prompt:

```console
Will you be using SFTP to copy migrated attachments remotely to the target Jira/Xray instance machine? (y/n)
```

Enter 'y' if you will be using SFTP, or 'n' if you will be copying attachments locally.

If you are not using SFTP, you will additionally be prompted for the path to the Xray attachment storage location. Enter the filepath where you want to store the migrated attachment files on the target Xray instance.

If the path you enter does not already exist, you can choose to have it created by entering 'y', or you can enter 'n' to cancel and enter a different path.

4. Three new directories will be created in your local copy of this repository:
- `/config` - Contains configuration files for Zephyr Scale and Xray.
- `/logs` - Log files generated by the migrations you run will be stored here.
- `/reports` - Any migration reconciliation reports you generate will be stored here.
5. If any of these directories already exist, they won't be modified by the script.
1. Once you see the messages `Starting...` and `xray-zephyr-migration`, the setup script is complete.
1. To check the status of the Xray Zephyr Docker container, run the following command:

```console
./run.sh status
```

8. The container should have a status of `running`. You are now ready to configure the migration.

### Migration configuration

Run the following command to configure settings for Zephyr Scale and Xray:

```console
./run.sh configure
```

> [!TIP]
> Note: you can edit the Zephyr Scale configuration directly by editing the `conn:` key of `./config/zephyr/zephyr-config.yml`

Follow the steps below at each prompt to complete the configuration:

_Zephyr_

1. Enter the keys of the Zephyr Scale projects to migrate, separated by commas (e.g. `PROJ123,PROJ456`).
1. Enter the domain of the Zephyr Scale server hosting the API, including the port if necessary (e.g. `https://your-zephyr-domain.com:8443`).
1. Enter the Jira user name to use for the Zephyr Scale API. Leave this blank if you are using a bearer token for authentication.
1. Enter the Jira user password to use for the Zephyr Scale API user. Leave this blank if you are using a bearer token for authentication.
1. Optionally enter the Zephyr Scale bearer token to use for API authentication, or just press enter if you are using user/password.

_Xray_

1. Enter the Xray database host URL (e.g. `localhost` or `your-xray-domain.com`).
1. Enter the Xray postgres database port (e.g. `5432`).
1. Enter the name of the Jira/Xray database (`jiradb` by default).
1. Enter the database user name to connect to the Jira/Xray database (`jirauser` by default).
1. Enter the database user password for the Jira/Xray database.

Once done, you should see the message `Excellent, your Xray Zephyr Docker is now configured!`.

Next, check the Xray config at `./config/xray/xray-config.yml` and Zephyr Scale config at `./config/zephyr/zephyr-config.yml` for the updated settings. You can modify these files directly to make any needed changes.

For an in-depth explanation of the settings within the configuration files, refer to the [Xray](./Docs/xray-configuration.md) and [Zephyr Scale](./Docs/zephyr-configuration.md) configuration documentation.

### Migration (Extract-Load)

1. Run the following command to create the project tables necessary for the migration to Xray:

```console
./run.sh extract
```

Enter 'extract' at the prompt to confirm that you're ready to create the project tables.

Once you see the messages `Zephyr test cycle additional attachments extraction script completed.` and `Zephyr extraction complete!`, the extraction process is complete.

2. Run the following command to start the migration:

```console
./run.sh migrate
```

Enter 'migrate' at the prompt to confirm that you're ready to migrate the data.

This script will read the data extracted from Zephyr Scale, transform it into Xray data, and save it to the Xray database.

You should see the following messages when the migration is complete:
- `Zephyr migration complete!`
- Please restart your Jira server and perform a re-index from the System settings panel for the changes to take effect.

The second of those messages mentions the steps outlined in the next section.

### Restart and re-index Jira server

1. To see the changes from the migration take effect, you must first restart your Jira server. You can do this by connecting to the server via SSH and running `service jira restart` with a user that has sufficient permissions, or by restarting the Docker container running the Jira server.
1. Once the Jira server is restarted, log in via the web browser and navigate to settings by clicking the gear icon in the top right corner and selecting "System" from the dropdown menu.
1. Scroll to the "Advanced" section in the left sidebar, and click "Indexing".
1. Select the "Full re-index" option, and click the "Re-index" button.
1. Click "Re-index" in the confirmation dialog to begin reindexing.
1. Once the progress bar reaches 100% and you see the message "Re-indexing is 100% complete," check that the migration has taken effect by navigating to the migrated Zephyr Scale project(s) in the web UI from the Projects tab at the top of the page.

### Reconciliation reporting

1. To generate a migration reconciliation report showing the data that was migrated from Zephyr Scale to Xray (and the data that wasn't migrated), run the following command:

```console
./run.sh report
```

2. The script will output a spreadsheet in the `/reports` directory, showing the reconciliation of data between Zephyr Scale and Xray. A command to open the report will be displayed in the console (e.g. `open ./reports/xray-report-2024-06-28T15:00:00Z.xlsx`). The command will open the report in your default spreadsheet application.

## Additional Information

### Start and setup script

You can run the both the setup and migration scripts at once with the following command:

```console
./run.sh go
```

### Cleaning migrated data

> [!WARNING]
> Cleaning migrated data means removing all the data that was copied to Xray as a result of running the migration. Only perform this step if you want to "rollback" the migration and remove the migrated data.

1. After you've run the migration scripts, you may choose to remove the migrated data from the Xray database. To do this, run the following command:

```console
./run.sh clean
```

2. Enter `clean` at the prompt to confirm that you're ready to remove the migrated data from Xray.
1. Once confirmed, the script will remove the migrated data from the Xray database. No data that already existed in Xray separately from the migration will be removed.

### Cleaning extracted data

> [!CAUTION]
> Cleaning extracted data means removing all the data that was extracted from Zephyr Scale and loaded into the Xray database. This data contains a ledger record of the resulting transformation and migration of the data into the Xray tables. If you remove the extracted data you will no longer be able to use this ledger record to clean the migrated data from Xray in a migration "rollback".

1. Once you've cleaned the migrated data from Xray, you may want to remove the Zephyr Scale tables that were created during the extraction process. To do this, run the following command:

```console
./run.sh clean-extracted-data
```

2. Enter `clean` at the prompt to confirm that you're ready to remove the Zephyr Scale tables from the Xray database.
1. Once confirmed, the script will remove the Zephyr Scaletables from the Xray database.

### Stopping the Docker container

When you have completed the migration, you will want to stop the migration's Docker container.

To bring down the Docker container, run the following command:

```console
./run.sh stop
```

This will not remove the container or its data.

### Removing the Docker container

To remove the Docker container and reset to its initial state, run the following:

```console
./run.sh reset
```

Enter `y` for yes at the prompt to confirm that you want to reset the container.

This command will stop and remove the container, and remove the following directories and their contents:
- `/config`
- `/logs`
- `/reports`
- `/source_attachments`

### Additional commands

You can see a full list of available commands by running:

```bash
./run.sh help
```

Some seldom-needed [additional commands](./Docs/additional-commands.md) are available.
