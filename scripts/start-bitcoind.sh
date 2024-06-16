#!/usr/bin/env bash
set -E -e -o pipefail

# TODO: Make this more extensible to allow configuring
# the right settings at the time of container startup.
exec bitcoind -regtest -datadir=/data/bitcoind
