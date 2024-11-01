## List available commands

You can see a full list of available commands by running:

```bash
./run.sh help
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
