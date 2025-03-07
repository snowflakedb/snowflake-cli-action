# Snowflake CLI Github Action

**Note:** Snowflake CLI Github Action is in Preview.

## Usage

Streamlines installing and using [Snowflake CLI](https://docs.snowflake.com/developer-guide/snowflake-cli-v2/index) in your CI/CD workflows. The CLI is installed in
isolated way making sure it won't conflict with dependencies of your project. Automatically set up
the input config file within the ~/.snowflake/ directory.

This actions enables automation of your Snowflake CLI tasks, such as deploying Native Apps or running Snowpark scripts within your Snowflake environment, etc.

## Inputs

### ` cli-version`

The specified Snowflake CLI version. For example `2.2.0`. If not specified then latest version will be used.

### `default-config-file-path`

Path to the configuration file (config.toml) in your repository. The path must be relative to root of repository.

## How to safely configure the action in your CI/CD workflow

To set up Snowflake credentials for a specific connection follow these steps.

1. **Add `config.toml` to Your Repository**:

   - Create a `config.toml` file at the root of your repository with an empty connection configuration. For example:

     ```toml
     default_connection_name = "myconnection"
     
     [connections]
     [connections.myconnection]
     user = ""
     ```

   This file serves as a template and is preferable to not contain any actual credentials.

2. **Generate a private key**:
   Generate a key pair for you snowflake account following this [user guide](https://docs.snowflake.com/en/user-guide/key-pair-auth).

3. **Store Credentials in GitHub Secrets**:

   - Store each credential (e.g., account, private key, passphrase) in GitHub Secrets. Refer to the [GitHub Actions documentation](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-a-repository) for detailed instructions on how to create and manage secrets for your repository.

4. **Map Secrets to Environment Variables**:

   - Map each secret to an environment variable using the format `SNOWFLAKE_CONNECTIONS_<connection-name>_<key>=<value>`. This overrides the credentials defined in `config.toml`. For example:

     ```yaml
     env:
       SNOWFLAKE_CONNECTIONS_MYCONNECTION_PRIVATE_KEY_RAW: ${{ secrets.SNOWFLAKE_PRIVATE_KEY_RAW }}
       SNOWFLAKE_CONNECTIONS_MYCONNECTION_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
     ```

5. **Configure the Snowflake CLI Action**:

   - Add the `default-config-file-path` parameter to the Snowflake CLI action step in your workflow file. This specifies the path to your `config.toml` file. For example:

     ```yaml
     - uses: snowflakedb/snowflake-cli-action@v1
       with:
         cli-version: "latest"
         default-config-file-path: "config.toml"
     ```

   Replace `latest` with a specific version of Snowflake CLI action if needed.

6. **[Optional] Set up a passphrase if private key is encrypted**:

   - Add an additional environment variable named `PRIVATE_KEY_PASSPHRASE` and set it to the private key passphrase. This passphrase will be used by Snowflake to decrypt the private key.

     ```yaml
     - name: Execute Snowflake CLI command
       env:
       PRIVATE_KEY_PASSPHRASE: ${{ secrets.PASSPHARSE }}
       run: |
         snow --version
         snow connection test
     ```

7. **[Extra] Using password instead of private key**:

   - Unset the environment variable `SNOWFLAKE_CONNECTIONS_MYCONNECTION_AUTHENTICATOR` and then add a new variable with the password as follows:

     ```yaml
     env:
       SNOWFLAKE_CONNECTIONS_MYCONNECTION_USER: ${{ secrets.SNOWFLAKE_USER }}
       SNOWFLAKE_CONNECTIONS_MYCONNECTION_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
       SNOWFLAKE_CONNECTIONS_MYCONNECTION_PASSWORD: ${{ secrets.SNOWFLAKE_PASSWORD }}
     ```

For more information in setting Snowflake credentials using environment variables, refer to the [Snowflake CLI documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/connecting/specify-credentials#how-to-use-environment-variables-for-snowflake-credentials). And the instructions on defining environment variables within your Github CI/CD workflow can be found [here](https://docs.github.com/en/actions/learn-github-actions/variables#defining-environment-variables-for-a-single-workflow).

## Full example usage

### Configuration file

```
default_connection_name = "myconnection"

[connections]
[connections.myconnection]
user = ""
```

### YAML file

```yaml
name: deploy
on: [push]
jobs:
  version:
    name: "Check Snowflake CLI version"
    runs-on: ubuntu-latest
    env:
      SNOWFLAKE_CONNECTIONS_MYCONNECTION_AUTHENTICATOR: SNOWFLAKE_JWT
      SNOWFLAKE_CONNECTIONS_MYCONNECTION_USER: ${{ secrets.SNOWFLAKE_USER }}
      SNOWFLAKE_CONNECTIONS_MYCONNECTION_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
      SNOWFLAKE_CONNECTIONS_MYCONNECTION_PRIVATE_KEY_RAW: ${{ secrets.SNOWFLAKE_PRIVATE_KEY_RAW }}

    steps:
      # Checkout step is necessary if you want to use a config file from your repo
      - name: Checkout repo
        uses: actions/checkout@v4
        with:
          persist-credentials: false

        # Snowflake CLI installation
      - uses: snowflakedb/snowflake-cli-action@v1.5
        with:
          cli-version: "latest"
          default-config-file-path: "config.toml"

        # Use the CLI
      - name: Execute Snowflake CLI command
        env:
          PRIVATE_KEY_PASSPHRASE: ${{ secrets.PASSPHARSE }} #Passphrase is only necessary if private key is encrypted.
        run: |
          snow --version
          snow connection test
```
