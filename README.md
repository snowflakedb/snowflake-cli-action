# Snowflake CLI Github Actions

**Note:** Snowflake CLI Github Actions is in Preview.

## Usage

Snowflake CLI Github Actions streamline installing and using [Snowflake CLI](https://docs.snowflake.com/developer-guide/snowflake-cli-v2/index) in your CI/CD workflows. The CLI is installed in
isolated way, making sure it won't conflict with dependencies of your project. It automatically sets up
the input configuration file within the `~/.snowflake/` directory.

The action enables automation of your Snowflake CLI tasks, such as deploying Native Apps or running Snowpark scripts within your Snowflake environment.

## Inputs

### `cli-version`

The specified Snowflake CLI version, for example `3.6.0`. If not provided, the latest version of the Snowflake CLI is used.

### `custom-github-ref`

The branch, tag, or commit to install from if you want to install the CLI directly from GitHub.

> **Note:** `cli-version` and `custom-github-ref` cannot be used together. Please specify only one of these arguments at a time.

### `use-oidc`

Boolean flag to enable OIDC authentication. When set to `true`, the action will configure the CLI to use GitHub's OIDC token for authentication with Snowflake, eliminating the need for storing private keys as secrets. Default is `false`.

### `default-config-file-path`

Path to the configuration file (`config.toml`) in your repository. The path must be relative to root of repository. The configuration file is not required when using a temporary connection (`-x` flag). Refer to the [Snowflake CLI documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/configure-connections#use-a-temporary-connection) for more details.

## Safely configure the action in your CI/CD workflow

### Use WIF OIDC authentication

_Requires Snowflake-CLI version 3.11 or above._

WIF OIDC authentication provides a secure and modern way to authenticate with Snowflake without storing private keys as secrets. This approach uses GitHub's OIDC (OpenID Connect) token to authenticate with Snowflake.

To set up WIF OIDC authentication, follow these steps:

1. **Configure WIF OIDC authentication in Snowflake**:

   You need to setup service user with OIDC workload identity type

   ```sql
   CREATE USER <username>
   TYPE = SERVICE
   WORKLOAD_IDENTITY = (
     TYPE = OIDC
     ISSUER = 'https://token.actions.githubusercontent.com'
     SUBJECT = '<your_subject>'
   )
   ```

   - _For examples of see [Example subject claims](https://docs.github.com/en/actions/reference/security/oidc#example-subject-claims) on GitHub._

   - _For more information about customizing your subject, see [OpenID Connect reference](https://docs.github.com/en/actions/reference/security/oidc) on GitHub._

   - _Follow more details, see the [Snowflake documentation](https://docs.snowflake.com/en/user-guide/workload-identity-federation) to set up OIDC authentication for your Snowflake account and configure the GitHub OIDC provider._

2. **Store your Snowflake account in GitHub secrets**:

   Store your Snowflake account identifier in GitHub Secrets. Refer to the [GitHub Actions documentation](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-a-repository) for detailed instructions.

3. **Configure the Snowflake CLI Action with OIDC authentication**:

   ```yaml
   name: Snowflake OIDC
   on: [push]
   
   permissions:
     id-token: write  # Required for OIDC token generation
     contents: read
   
   jobs:
     oidc-job:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
           with:
             persist-credentials: false
         - name: Setup Snowflake cli
           uses: snowflakedb/snowflake-cli-action@v2.0
           with:
             use-oidc: true
             cli-version: "3.11"
         - name: test connection
           env:
             SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
           run: snow connection test -x
   ```

### Alternative authentication methods

The following methods can be used as alternatives to OIDC authentication:

#### Prerequisites for key-based authentication

These steps are a prerequisite for both key-based methods:

1. **Generate a private key**:

   Generate a key pair for your snowflake account following this [user guide](https://docs.snowflake.com/en/user-guide/key-pair-auth).

2. **Store credentials in GitHub secrets**:

   Store each credential, such as account, private key, and passphrase in GitHub Secrets. Refer to the [GitHub Actions documentation](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-a-repository) for detailed instructions on how to create and manage secrets for your repository.

#### Use a temporary connection

To set up Snowflake credentials for a temporary connection, follow these steps.

1. **Map secrets to environment variables**:

    Map each secret to an [environment variable](https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/configure-connections#use-environment-variables-for-snowflake-credentials) using the format `SNOWFLAKE_<key>=<value>`. For example:

    ```yaml
    env:
      SNOWFLAKE_PRIVATE_KEY_RAW: ${{ secrets.SNOWFLAKE_PRIVATE_KEY_RAW }}
      SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
    ```

2. **Configure the Snowflake CLI Action**:
    If you want to use the latest version, you don't need to include the `cli-version` parameter. Otherwise, include it along with a specific version.

    Example:

    ```yaml
    - uses: snowflakedb/snowflake-cli-action@v1.5
      with:
        cli-version: "3.6.0"
    ```

3. **[Optional] Set up a passphrase if private key is encrypted**:

    Add an environment variable named `PRIVATE_KEY_PASSPHRASE` and set it to the private key passphrase. This passphrase is used by Snowflake to decrypt the private key.

    ```yaml
    - name: Execute Snowflake CLI command
      env:
        PRIVATE_KEY_PASSPHRASE: ${{ secrets.PASSPHARSE }}
      run: |
        snow --version
        snow connection test -x
    ```

4. **[Extra] Use a password instead of a private key**:

     Unset the environment variable `SNOWFLAKE_AUTHENTICATOR`, and then add a new variable with the password as follows:

     ```yaml
     env:
       SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_USER }}
       SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
       SNOWFLAKE_PASSWORD: ${{ secrets.SNOWFLAKE_PASSWORD }}
     ```

    > **Note**: To enhance your experience when using a password and MFA, it is recommended to configure MFA caching. For more information, refer to the [Snowflake CLI documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/configure-connections#use-multi-factor-authentication-mfa).

For more information in setting Snowflake credentials using environment variables, refer to the [Snowflake CLI documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/connecting/specify-credentials#how-to-use-environment-variables-for-snowflake-credentials). And the instructions on defining environment variables within your Github CI/CD workflow can be found [here](https://docs.github.com/en/actions/learn-github-actions/variables#defining-environment-variables-for-a-single-workflow).

#### Use a configuration file

To set up Snowflake credentials for a specific connection, follow these steps.

1. **Add `config.toml` to your repository**:

   Create a `config.toml` file at the root of your repository with an empty connection configuration. For example:

   ```toml
   default_connection_name = "myconnection"

   [connections.myconnection]
   ```

   This file serves as a template and should not contain actual credentials.

2. **Map secrets to environment variables**:

   Map each secret to an environment variable using the format `SNOWFLAKE_CONNECTIONS_<connection-name>_<key>=<value>`. This overrides the credentials defined in `config.toml`. For example:

   ```yaml
   env:
     SNOWFLAKE_CONNECTIONS_MYCONNECTION_PRIVATE_KEY_RAW: ${{ secrets.SNOWFLAKE_PRIVATE_KEY_RAW }}
     SNOWFLAKE_CONNECTIONS_MYCONNECTION_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
   ```

3. **Configure the Snowflake CLI action**:

   Add the `default-config-file-path` parameter to the Snowflake CLI action step in your workflow file. This specifies the path to your `config.toml` file. For example:

   ```yaml
   - uses: snowflakedb/snowflake-cli-action@v1
     with:
       cli-version: "3.6.0"
       default-config-file-path: "config.toml"
   ```

   Replace `latest` with a specific version of Snowflake CLI action, if needed.

4. **[Optional] Set up a passphrase if private key is encrypted**:

   Add an additional environment variable named `PRIVATE_KEY_PASSPHRASE` and set it to the private key passphrase. This passphrase is used by Snowflake to decrypt the private key.

   ```yaml
   - name: Execute Snowflake CLI command
     env:
     PRIVATE_KEY_PASSPHRASE: ${{ secrets.PASSPHARSE }}
     run: |
       snow --version
       snow connection test
   ```

5. **[Extra] Use a password instead of private key**:

   Unset the environment variable `SNOWFLAKE_CONNECTIONS_MYCONNECTION_AUTHENTICATOR`, and then add a new variable with the password as follows:

   ```yaml
   env:
     SNOWFLAKE_CONNECTIONS_MYCONNECTION_USER: ${{ secrets.SNOWFLAKE_USER }}
     SNOWFLAKE_CONNECTIONS_MYCONNECTION_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
     SNOWFLAKE_CONNECTIONS_MYCONNECTION_PASSWORD: ${{ secrets.SNOWFLAKE_PASSWORD }}
   ```

   > **Note**: To enhance your experience when using a password and MFA, it is recommended to configure MFA caching. For more information, refer to the [Snowflake CLI documentation](https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/configure-connections#use-multi-factor-authentication-mfa).

## Usage examples

### Use a temporary connection

Yaml file:

```yaml
name: deploy
on: [push]

jobs:
   version:
      name: "Check Snowflake CLI version"
      runs-on: ubuntu-latest
      steps:
         # Snowflake CLI installation
         - uses: snowflakedb/snowflake-cli-action@v1.5

            # Use the CLI
         - name: Execute Snowflake CLI command
           env:
              SNOWFLAKE_AUTHENTICATOR: SNOWFLAKE_JWT
              SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_USER }}
              SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
              SNOWFLAKE_PRIVATE_KEY_RAW: ${{ secrets.SNOWFLAKE_PRIVATE_KEY_RAW }}
              PRIVATE_KEY_PASSPHRASE: ${{ secrets.PASSPHARSE }} # Passphrase is only necessary if private key is encrypted.
           run: |
              snow --help
              snow connection test -x
```

### Use a configuration file

Configuration file:

```
default_connection_name = "myconnection"

[connections.myconnection]
```

Yaml file:

```yaml
name: deploy
on: [push]
jobs:
  version:
    name: "Check Snowflake CLI version"
    runs-on: ubuntu-latest
    steps:
      # Checkout step is necessary if you want to use a config file from your repo
      - name: Checkout repo
        uses: actions/checkout@v4
        with:
          persist-credentials: false

        # Snowflake CLI installation
      - uses: snowflakedb/snowflake-cli-action@v1.5
        with:
          default-config-file-path: "config.toml"

        # Use the CLI
      - name: Execute Snowflake CLI command
        env:
          SNOWFLAKE_CONNECTIONS_MYCONNECTION_AUTHENTICATOR: SNOWFLAKE_JWT
          SNOWFLAKE_CONNECTIONS_MYCONNECTION_USER: ${{ secrets.SNOWFLAKE_USER }}
          SNOWFLAKE_CONNECTIONS_MYCONNECTION_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
          SNOWFLAKE_CONNECTIONS_MYCONNECTION_PRIVATE_KEY_RAW: ${{ secrets.SNOWFLAKE_PRIVATE_KEY_RAW }}
          PRIVATE_KEY_PASSPHRASE: ${{ secrets.PASSPHARSE }} #Passphrase is only necessary if private key is encrypted.
        run: |
          snow --help
          snow connection test
```

### Install from a GitHub branch or tag

To install Snowflake CLI from a specific branch, tag, or commit in the GitHub repository (for example, to test unreleased features or a fork), use the following configuration:
This feature is available from snowflake-cli-action v1.6

```yaml
- uses: snowflakedb/snowflake-cli-action@v1.6
  with:
    custom-github-ref: "feature/my-branch"   # or a tag/commit hash
```

This will install the CLI from the specified branch, tag, or commit. You can combine this with other inputs as needed.
