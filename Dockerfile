# syntax=docker/dockerfile:1

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG} AS with-keys-and-scripts

COPY config/signing-keys /keys/
COPY scripts/start-bitcoind.sh /scripts/
COPY scripts/bitcoind-info.sh /scripts/

ARG BASE_IMAGE_NAME
ARG BASE_IMAGE_TAG
FROM ${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

ARG USER_NAME
ARG GROUP_NAME
ARG USER_ID
ARG GROUP_ID
ARG BITCOIN_CORE_VERSION
ARG PACKAGES_TO_INSTALL

# hadolint ignore=DL4006,SC2086,SC3009
RUN \
    --mount=type=bind,target=/scripts,from=with-keys-and-scripts,source=/scripts \
    --mount=type=bind,target=/keys,from=with-keys-and-scripts,source=/keys \
    set -E -e -o pipefail \
    && export HOMELAB_VERBOSE=y \
    # Install dependencies. \
    && homelab install gnupg \
    && homelab install ${PACKAGES_TO_INSTALL:?} \
    # Create the user and the group. \
    && homelab add-user \
        ${USER_NAME:?} \
        ${USER_ID:?} \
        ${GROUP_NAME:?} \
        ${GROUP_ID:?} \
        --create-home-dir \
    # Import the gpg public keys used for signing the bitcoin core releases. \
    # We attempt five times to handle any transient errors. \
    && for key in $(cat /keys/signing-keys); do \
            echo "Importing key ${key:?}"; \
            gpg --batch --keyserver hkp://keyserver.ubuntu.com --recv-keys ${key:?} || \
            gpg --batch --keyserver hkp://keyserver.ubuntu.com --recv-keys ${key:?} || \
            gpg --batch --keyserver hkp://keys.openpgp.org --recv-keys ${key:?} || \
            gpg --batch --keyserver hkp://keys.openpgp.org --recv-keys ${key:?} \
            ; \
        done \
    # Download and verify the release. \
    && mkdir -p /build \
    && homelab download-file-to \
        "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_CORE_VERSION:?}/bitcoin-${BITCOIN_CORE_VERSION:?}-$(arch)-linux-gnu.tar.gz" \
        /build \
    && homelab download-file-to \
        "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_CORE_VERSION:?}/SHA256SUMS.asc" \
        /build \
    && homelab download-file-to \
        "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_CORE_VERSION:?}/SHA256SUMS" \
        /build \
    && gpg --verbose --verify /build/SHA256SUMS.asc \
    # Install the release. \
    && homelab install-tar-dist \
        "file:///build/bitcoin-${BITCOIN_CORE_VERSION:?}-$(arch)-linux-gnu.tar.gz" \
        "$(grep "bitcoin-${BITCOIN_CORE_VERSION:?}-$(arch)-linux-gnu.tar.gz" /build/SHA256SUMS | cut -d ' ' -f 1)" \
        bitcoin \
        bitcoin-${BITCOIN_CORE_VERSION:?} \
        ${USER_NAME:?} \
        ${GROUP_NAME:?} \
    && /opt/bitcoin/libexec/test_bitcoin --show_progress \
    && rm /opt/bitcoin/bin/bitcoin-qt /opt/bitcoin/libexec/{bitcoin-gui,test_bitcoin} \
    # Set up symlink for the binary at a location accessible through $PATH. \
    && ln -sf /opt/bitcoin/bin/bitcoind /opt/bin/bitcoind \
    && ln -sf /opt/bitcoin/bin/bitcoin-cli /opt/bin/bitcoin-cli \
    && ln -sf /opt/bitcoin/bin/bitcoin-tx /opt/bin/bitcoin-tx \
    && ln -sf /opt/bitcoin/bin/bitcoin-util /opt/bin/bitcoin-util \
    && ln -sf /opt/bitcoin/bin/bitcoin-wallet /opt/bin/bitcoin-wallet \
    # Set up the data dir. \
    && mkdir -p /data/bitcoind/{config,data} \
    && mkdir -p /home/${USER_NAME:?}/.bitcoin \
    && echo "datadir=/data/bitcoind/data" > /home/${USER_NAME:?}/.bitcoin/bitcoin.conf \
    && chown -R ${USER_NAME:?}:${GROUP_NAME:?} /data/bitcoind /home/${USER_NAME:?}/.bitcoin \
    # Copy the start-botcoind.sh and bitcoind-info scripts. \
    && cp /scripts/{start-bitcoind,bitcoind-info}.sh /opt/bitcoin/bin \
    && ln -sf /opt/bitcoin/bin/start-bitcoind.sh /opt/bin/start-bitcoind \
    && ln -sf /opt/bitcoin/bin/bitcoind-info.sh /opt/bin/bitcoind-info \
    # Clean up. \
    && rm -rf /root/.gnupg \
    && rm -rf /build \
    && homelab remove gpg \
    && homelab cleanup

HEALTHCHECK \
    --start-period=15s --interval=30s --timeout=3s \
    CMD bitcoind-info

USER ${USER_NAME}:${GROUP_NAME}
WORKDIR /home/${USER_NAME}

CMD ["start-bitcoind"]
STOPSIGNAL SIGTERM
