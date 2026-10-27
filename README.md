# X16 Open


## Overview

The X16 open kernel is an open source operating system for the Commander X16.

It is built around these ideas:

- **Single user, single process.**
- **Everything is a file.** Devices are accessed through file handles,
  using `open`, `read`, `write`, and `close`.
- **Drivers are modular.** The main drivers live in ROM and are
  registered at boot. Additional drivers can be loaded at runtime into
  low RAM or banked RAM.
- **The kernel is thin.** It dispatches calls to drivers, manages the
  file table, and provides a small number of primitives. Everything
  else is the driver's responsibility.

## Manual

The system manual is found [here](docs/x16book.pdf).
