#!/usr/bin/env bash
set -E -e -o pipefail

set_umask() {
    # Configure umask to allow write permissions for the group by default
    # in addition to the owner.
    umask 0002
}

start_bitcoind() {
    # TODO: Make this more extensible to allow configuring
    # the right settings at the time of container startup.
    exec bitcoind -regtest -datadir=/data/bitcoind
}

set_umask
start_bitcoind
