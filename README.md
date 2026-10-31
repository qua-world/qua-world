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

Terraform splits into layers by credentials. `terraform/bootstrap/` runs
rarely, by hand, with an owner's credentials. It creates the
`qua-world-infrastructure` Google Cloud project, the state buckets, and the
deployer service accounts that continuous integration impersonates through
Workload Identity Federation. No key is stored anywhere.

Each layer keeps state in its own bucket: `qua-world-tfstate` for bootstrap,
`qua-world-infrastructure-tfstate` for the layer continuous integration
applies. The deployers can reach the second bucket alone, so continuous
integration can't read or rewrite the state that defines its own
credentials.

### Run the first-time bootstrap

You need [Terraform](https://terraform.io), the
[gcloud CLI](https://cloud.google.com/sdk/docs/install), the
[GitHub CLI](https://cli.github.com), a Google account that can create
projects and link billing, and admin on this repository.

The script calls `gcloud`, which keeps its own credentials, while Terraform
reads application default credentials, so log in to both:

```sh
gcloud auth login
gcloud auth application-default login
gh auth login

scripts/bootstrap.sh
```

The script prompts for the billing account to attach; set
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

Terraform also creates empty Secret Manager secrets for the GitHub App the
CI-applied layer authenticates as. [Create the GitHub
App](docs/how-to/create-github-app.md) registers the App and fills them.

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
