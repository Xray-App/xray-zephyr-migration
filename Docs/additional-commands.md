## List available commands

You can see a full list of available commands by running:

```bash
./run.sh help
```

The output of which is as follows:

```plaintext
* go
  One shot start and setup

* start
  Start xray-zephyr-migration container

* stop
  Stop xray-zephyr-migration container

* status
  Show the status of the xray-zephyr-migration container

* configure
  Collect the Zephyr and Xray configuration

* extract
  Create the project tables necessary for the migration to Xray

* migrate
  Migrate the projects

* report
  Generate the reconciliation report

* clean
  Clean the migration

* clean-rest
  Clean extracted tables

* reset
  Reset the Xray Data Migration
```

## Checking the status of the containers

To check the status of the Zephyr migration container, run the following command:

```bash
./run.sh status
```

The three possible statuses for the Zephyr migration container are:
- `unknown`: The container was not found. You can create any missing containers with `./run.sh start`.
- `running`: The container was found and is running.
- `stopped`: The container was found and has stopped.
