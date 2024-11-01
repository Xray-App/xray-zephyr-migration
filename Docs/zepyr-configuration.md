# Zephyr Configuration

NOTE: If you need to reset the Zephyr configuration to its default values at any point, you can do so by running the following command:

```bash
git restore data-engineering/config/zephyr/zephyr-config.yml
```

## Configuration Options

`project_keys` - Specify the list of Zephyr projects to be migrated by adding their respective project keys as an array.

Example:
```yml
project_keys: ["PK1", "PK2"]
```

`test_case_statuses_map` - Specify how Zephyr test case statuses should be mapped to Xray issue statuses.

Example:
```yml
test_case_statuses_map:
  Approved: Open
  Deprecated: Closed
  Draft: Open
```

If the status is not found in the `test_case_statuses_map`, the `default_test_case_status` will be used.

Example:
```yml
default_test_case_status: Open
```

`test_plan_statuses_map` - Specify how Zephyr test plan statuses should be mapped to Xray issue statuses.

Example:
```yml
test_plan_statuses_map:
  Approved: Open
  Deprecated: Closed
  Draft: Open
```

If the status is not found in the `test_plan_statuses_map`, the `default_test_plan_status` will be used.

Example:
```yml
default_test_plan_status: Open
```

`test_run_statuses_map` - Specify how Zephyr test run statuses should be mapped to Xray issue statuses.

Example:
```yml
test_run_statuses_map:
  Not Executed: TODO
  In Progress: EXECUTING
  Pass: PASS
  Fail: FAIL
  Blocked: ABORTED
```

If the status is not found in the `test_run_statuses_map`, the `default_test_run_status` will be used.

Example:
```yml
default_test_run_status: TODO
```

`priorities_map` - Specify how Zephyr priorities should be mapped to Xray priorities.

Example:
```yml
priorities_map:
  Low: Low
  Normal: Medium
  High: High
```

If the priority is not found in the `priorities_map`, the `default_priority` will be used.

Example:
```yml
default_priority: Medium
```

`default_user_key` - Specify the default user key to be used during migration. This user will be used as a fallback where a Zephyr user is either not mapped or found.

Example:
```yml
default_user_key: JIRAUSER10000
```

`add_to_admin` - This flag specifies whether or not the default user should be given the Administrators project role.

Example:
```yml
add_to_admin: true
```

## Connection Options

The following options should be added to the `conn` section of the `zephyr-config.yml` file.

Example:
```yml
conn:
  domain: https://jira-instance.com:8443
  username: admin
  password: jir4
```

`domain` - Specify the URL of the Jira server.

Example:
```yml
domain: https://jira-instance.com:8443
```

`username` - Specify the username to access the Jira server.

Example:
```yml
username: admin
```

`password` - Specify the password of the previously specified user to access the Jira server.

Example:
```yml
password: jir4
```
