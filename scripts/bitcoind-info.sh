#!/usr/bin/env bash

set -E -e -o pipefail

BITCOIN_CLI="bitcoin-cli"
JQ="jq"

getinfo() {
    local chain="${1:?}"
    ${BITCOIN_CLI:?} -chain="${chain:?}" -getinfo
}

netinfo() {
    local chain="${1:?}"
    ${BITCOIN_CLI:?} -chain="${chain:?}" -netinfo 4
}

blockchain_info() {
    local chain="${1:?}"
    ${BITCOIN_CLI:?} -chain="${chain:?}" getblockchaininfo
}

block_count() {
    local chain="${1:?}"
    ${BITCOIN_CLI:?} -chain="${chain:?}" getblockcount
}

block_hash() {
    local chain="${1:?}"
    local block_height="${2:?}"
    ${BITCOIN_CLI:?} -chain="${chain:?}" getblockhash "${block_height:?}"
}

block_by_hash() {
    local chain="${1:?}"
    local hash="${2:?}"
    ${BITCOIN_CLI:?} -chain="${chain:?}" getblock "${hash:?}"
}

block_timestamp() {
    local chain="${1:?}"
    local hash="${2:?}"
    block_by_hash "${chain:?}" "${hash:?}" | ${JQ:?} '.time'
}

blockchain_verification_progress() {
    local chain="${1:?}"
    blockchain_info "${chain:?}" | ${JQ:?} '.verificationprogress'
}

blockchain_size_on_disk_bytes() {
    local chain="${1:?}"
    blockchain_info "${chain:?}" | ${JQ:?} '.size_on_disk'
}

bitcoind_info() {
    local chain="${1:-main}"

    local local_block_count="$(block_count "${chain:?}")"
    echo "Local Best Block count: ${local_block_count:?}"

    local local_block_hash="$(block_hash "${chain:?}" ${local_block_count:?})"
    echo "Local Best Block hash @${local_block_count:?} : ${local_block_hash:?}"

    local local_block_timestamp="$(block_timestamp "${chain:?}" "${local_block_hash:?}")"
    echo "Local Best Block timestamp is: $(date -d @${local_block_timestamp:?})"

    local current_time=$(date +%s)
    local time_delta="$[${current_time:?} - ${local_block_timestamp:?}]"
    local relative_time_delta="$(echo "${time_delta:?}" | awk '{printf "%d days, %d hours %d mins %d secs\n",$1/(60*60*24),$1/(60*60)%24,$1%(60*60)/60,$1%60}')"
    echo "Delta from HEAD is: ${relative_time_delta:?}"

    local progress_fraction="$(blockchain_verification_progress ${chain:?})"
    echo "Verification Progress: $(awk -vfrac=${progress_fraction} 'BEGIN{printf "%.2f", frac * 100}') %"

    local size_on_disk_bytes="$(blockchain_size_on_disk_bytes ${chain:?})"
    echo "Size on Disk: $(awk -vbytes=${size_on_disk_bytes} 'BEGIN{printf "%.2f", bytes / 1024 / 1024 / 1024}') GB"
}

dump_bitcoind_info() {
    local chain="${1:-main}"

    getinfo "${chain:?}"
    netinfo "${chain:?}"
}

dump_bitcoind_info "$@"
bitcoind_info "$@"
