# Xray Configuration

NOTE: If you need to reset the Xray configuration to its default values at any point, you can do so by running the following command:

```bash
git restore data-engineering/config/xray/xray-config.yml
```

## Configuration Options

`project_name_prefix` - Specify the prefix to be added to the project name to avoid conflicts with existing projects in Xray.

Example:
```yml
project_name_prefix: "Zephyr"
```

`project_name_suffix` - Specify the suffix to be added to the project name to avoid conflicts with existing projects in Xray.

Example:
```yml
project_name_suffix: "Xray"
```

`project_key_suffix` - Specify the suffix to be added to the project key to avoid conflicts with existing project keys.
Example:
```yml
project_key_suffix: "X"
```

`jira_data_path` - Specify the path to the Jira attachment data directory on the remote server.

Example:
```yml
jira_data_path: /var/atlassian/application-data/jira/data/attachments/
```

## SSH Options

The following options should be added to the `ssh` section of the `xray-config.yml` file.

Example:
```yml
ssh:
  host: ssh.example.com
  username: user
  password: password
```

`host` - Specify the hostname of the remote server.

Example:
```yml
host: ssh.example.com
```

`username` - Specify the username to access the remote server.

Example:
```yml
username: user
```

`password` - Specify the password of the previously specified user to access the remote server.

Example:
```yml
password: password
```

## Database Options

The following options should be added to the `db` section of the `xray-config.yml` file.


Example:
```yml
db:
  host: jira-database-instance.com
  port: 5432
  database: jiradb
  username: jirauser
  password: jirapassword
```

`host` - Specify the hostname of the database server.

Example:
```yml
host: jira-database-instance.com
```

`port` - Specify the port number of the database server.

Example:
```yml
port: 5432
```

`database` - Specify the name of the database.

Example:
```yml
database: jiradb
```

`username` - Specify the username to access the database.

Example:
```yml
username: jirauser
```

`password` - Specify the password of the previously specified user to access the database.

Example:
```yml
password: jirapassword
```
