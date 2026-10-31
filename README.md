<!--
SPDX-FileCopyrightText: 2020 Alex Brandt

SPDX-License-Identifier: MIT
-->

# Description

GUI Client and Client Interfaces for [qua.world]

A GUI client for interacting with the qua.world massively multiplayer online
gaming environment and client interfaces for creating bots, automation, and
other actors in the game world.

## Architecture

The [architecture decision records](docs/adr/) cover how this client fits with
the qua.world world-server and the other actors that connect to it.

## Getting started

The `partir-glut` executable documents its usage in its help output.

## Terraform

`terraform/bootstrap/` creates what continuous integration needs to run
Terraform: the `qua-world-infrastructure` Google Cloud project, the state
buckets, and deployer service accounts that workflows impersonate through
Workload Identity Federation, so no service account key exists. An owner
applies it by hand, rarely.

Bootstrap keeps its state in `qua-world-tfstate`. The deployers can reach
only `qua-world-infrastructure-tfstate`, so continuous integration can't read
or rewrite the state that defines its own credentials.

Any workflow in this repository can act as the read-only deployer. Only
workflows listed in `deployer_rw_workflow_refs`, running on `develop`, can act
as the read-write deployer.

### Run the first-time bootstrap

You need [just](https://just.systems), [Terraform](https://terraform.io), the
[gcloud CLI](https://cloud.google.com/sdk/docs/install), the
[GitHub CLI](https://cli.github.com), a Google account that can create
projects and link billing, and admin on this repository.

Log in three times: `gcloud` keeps its own credentials, Terraform reads
application default credentials, and `gh` sets the Actions variables:

```sh
gcloud auth login
gcloud auth application-default login
gh auth login

just bootstrap
```

The recipe prompts for the billing account to attach; set
`TF_VAR_billing_account_id` to run it without a terminal. It applies the
layer, then sets the `GCP_WORKLOAD_IDENTITY_PROVIDER`,
`GCP_DEPLOYER_RO_EMAIL`, and `GCP_DEPLOYER_RW_EMAIL` Actions variables that
workflows authenticate with. Every step is idempotent, so a partial failure
is safe to re-run.

To confirm continuous integration can reach its state, dispatch the
**Deployer access** workflow from `develop`:

```sh
gh workflow run deployer-access.yml --ref develop
```

Bootstrap also creates empty Secret Manager secrets for the two GitHub Apps
Terraform authenticates to GitHub as: a read-only App for plan and a
read-write App for apply. [Create the Terraform GitHub
Apps](docs/how-to/create-terraform-github-apps.md) registers them and fills
the secrets.

## Reporting issues

If you believe you've found an error or have a suggestion for a new feature,
please file it on [GitHub].

If you would like to contribute a fix or new feature, please submit a pull
request. [CONTRIBUTING.md](CONTRIBUTING.md) covers the conventions a review
expects.

## License

This project uses the [MIT License](LICENSE).

[GitHub]: https://github.com/qua-world/qua-world/issues
[qua.world]: https://github.com/qua-world
