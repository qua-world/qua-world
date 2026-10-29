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

This repository is becoming the qua.world **polyglot monorepo**, built with
buck2. It holds the Haskell **client** today. The authoritative Erlang/OTP
**world-server** will join it as a sibling build target. The architecture
decision records in [`docs/adr/`](docs/adr/) cover the monorepo layout, the
world-server, and how actors connect to it.

## Getting started

The `partir-glut` executable documents its usage in its help output.

## Reporting issues

If you believe you've found an error or have a suggestion for a new feature,
please file it on [GitHub].

If you would like to contribute a fix or new feature, please submit a pull
request. [CONTRIBUTING.md](CONTRIBUTING.md) covers the conventions a review
expects.

## License

This project uses the [MIT License](LICENSE).

[GitHub]: https://github.com/qua-world/partir.qua.world/issues
[qua.world]: https://github.com/qua-world
