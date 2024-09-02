#!/usr/bin/env bash
set -E -e -o pipefail

bitcoind_config="/data/bitcoind/config/bitcoin.conf"

set_umask() {
    # Configure umask to allow write permissions for the group by default
    # in addition to the owner.
    umask 0002
}

setup_bitcoind_config() {
    echo "Checking for existing bitcoind config ..."
    echo

    if [ -f "${bitcoind_config:?}" ]; then
        echo "Existing bitcoind configuration \"${bitcoind_config:?}\" found"
    else
        echo "Generating bitcoind configuration at ${bitcoind_config:?}"
        cat << EOF > ${bitcoind_config:?}
datadir=/data/bitcoind/data

nodebuglogfile=1
logips=1
loglevelalways=1
logsourcelocations=0
logthreadnames=1
logtimestamp=1
printtoconsole=1

server=1
rest=0
listen=0
listenonion=0
noonion=1
upnp=0
onlynet=ipv4

i2pacceptincoming=0

disablewallet=1

chain=regtest
EOF
    fi

    echo
    echo
}

start_bitcoind() {
    exec bitcoind -conf=${bitcoind_config:?}
}

set_umask
setup_bitcoind_config
start_bitcoind
