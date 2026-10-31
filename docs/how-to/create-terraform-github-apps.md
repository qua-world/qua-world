<!--
SPDX-FileCopyrightText: 2026 Alex Brandt

SPDX-License-Identifier: MIT
-->

# Create the Terraform GitHub Apps

Two GitHub Apps authenticate the `github` Terraform provider in continuous
integration. Plan runs whatever workflow a pull request supplies, so it uses
a read-only App. Apply uses a read-write App whose key only the read-write
deployer can read.

You need an owner role in the `qua-world` organization and permission to add
secret versions in the `qua-world-infrastructure` project. Run the
[first-time bootstrap](../../README.md#run-the-first-time-bootstrap) before
starting, so the secrets exist.

## Create the Apps

Create each App at
<https://github.com/organizations/qua-world/settings/apps/new> with:

- **GitHub App name**: `qua-world-terraform-plan` or
  `qua-world-terraform-apply`. GitHub credits each change the App makes to
  this name.
- **Homepage URL**: <https://github.com/qua-world/qua-world>.
- **Webhook**: clear **Active**. Terraform calls the API and never receives
  events.
- **Where can this GitHub App be installed?**: **Only on this account**. A
  leaked key reaches every account that installs the App.
- Permissions, everything else **No access**:

  | Permission | `qua-world-terraform-plan` | `qua-world-terraform-apply` |
  | --- | --- | --- |
  | Repository → `Administration` | Read-only | Read and write |
  | Repository → `Environments` | Read-only | Read and write |
  | Repository → `Issues` | Read-only | Read and write |
  | Repository → `Metadata` | Read-only | Read-only |
  | Organization → `Administration` | Read-only | Read and write |

  Extend both Apps when a Terraform resource fails without a permission.

Then, for each App:

1. On the App's **General** page, note the **App ID**. Under **Private
   keys**, generate and download one. GitHub shows it once, so regenerate
   it if lost.
2. **Install App** → **Install** on `qua-world` → **All repositories**, so
   Terraform can refresh every repository it declares.

## Store the credentials

Re-run the bootstrap, which prompts for each App's ID and private key path:

```sh
just bootstrap
```

Set `TERRAFORM_PLAN_APP_ID`, `TERRAFORM_PLAN_APP_PRIVATE_KEY_FILE`,
`TERRAFORM_APPLY_APP_ID`, and `TERRAFORM_APPLY_APP_PRIVATE_KEY_FILE`
beforehand to answer without the prompts.

Shred each `.pem` file once the bootstrap has stored it.
