<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# Create the GitHub App

The `github` Terraform provider authenticates as a GitHub App installed on the
`qua-world` organization. These steps register that App and store its
credentials in the Secret Manager secrets `terraform/bootstrap/` created
empty.

You need an owner role in the organization and permission to add secret
versions in the `qua-world-infrastructure` project. Run the
[first-time bootstrap](../../README.md#run-the-first-time-bootstrap) before
starting, so the secrets exist.

## Register the App

1. Open <https://github.com/organizations/qua-world/settings/apps/new>.

2. Set **GitHub App name** to `qua-world-terraform` and **Homepage URL** to
   <https://github.com/qua-world/qua-world>.

3. Clear **Webhook → Active**. Terraform calls the API and never receives
   events.

4. Grant these permissions and no others:

   - **Repository → Administration**, read and write: repository settings
     and rulesets.
   - **Repository → Environments**, read and write: deployment environments
     and their protection rules.
   - **Repository → Issues**, read and write: labels.
   - **Organization → Administration**, read and write: organization
     settings and allowed actions.

   GitHub adds **Repository → Metadata**, read-only, on its own. Leave it.
   Extend the set when a Terraform resource fails without a permission.

5. Under **Where can this GitHub App be installed?** choose **Only on this
   account**.

6. Select **Create GitHub App**, then record the **App ID** shown on the
   General tab.

7. Under **Private keys**, select **Generate a private key**. GitHub hands
   over the `.pem` file once and keeps only its fingerprint.

## Install the App on the organization

1. From the App's **Install App** tab, install it on `qua-world` with **All
   repositories** selected, so Terraform can refresh every repository it
   declares.

2. Record the installation ID. It's the last path segment of the URL you
   land on:

   ```text
   https://github.com/organizations/qua-world/settings/installations/<ID>
   ```

## Store the credentials

Re-run the bootstrap, which prompts for the App ID, installation ID, and
private key path:

```sh
just bootstrap
```

Export `GITHUB_APP_ID`, `GITHUB_APP_INSTALLATION_ID`, and
`GITHUB_APP_PRIVATE_KEY_PATH` beforehand to answer the prompts without a
terminal.

Then destroy the downloaded key:

```sh
shred --remove ~/Downloads/qua-world-terraform.*.private-key.pem
```
