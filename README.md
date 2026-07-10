# Description

GUI Client and Client Interfaces for [qua.world]

A GUI client for interacting with the qua.world MMO gaming environment and
client interfaces for creating bots, automation, and other actors in the game
world.

# Architecture

This repository is becoming the qua.world **polyglot monorepo**, built with
buck2. It holds the Haskell **client** today; the authoritative Erlang/OTP
**world-server** will join it as a sibling build target. See
[ADR 0001](docs/adr/0001-architecture.md) for the client/server boundary and
monorepo layout, and the rest of [`docs/adr/`](docs/adr/) for the decisions
behind it.

# Getting Started

Usage is pretty straightforward and documented in the help output in the partir
executable.

# Reporting Issues

Any issues discovered should be recorded on [Github].  If you believe you've
found an error or have a suggestion for a new feature, please ensure that it is
reported.

If you would like to contribute a fix or new feature, please submit a pull
request.  This project follows [git flow].

# License

This project is released under the [MIT License](LICENSE).

[git flow]: http://nvie.com/posts/a-successful-git-branching-model/
[Github]: https://github.com/qua-world/partir.qua.world/issues
[qua.world]: https://github.com/qua-world
