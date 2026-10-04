# syntax=docker/dockerfile:1.7

FROM ubuntu:24.04

ARG TARGETARCH=amd64
ARG IMAGE_VERSION=1.0.0
ARG TRADER_UID=10001
ARG TRADER_GID=10001
ARG MT5_INSTALLER_URL=https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
ARG WEBVIEW2_INSTALLER_URL=https://go.microsoft.com/fwlink/p/?LinkId=2124703
ARG MT5_INSTALLER_SHA256=
ARG WEBVIEW2_INSTALLER_SHA256=

LABEL org.opencontainers.image.title="MetaTrader 5 on Wine with noVNC" \
      org.opencontainers.image.description="Single-container, browser-accessible MetaTrader 5 runtime for amd64 Linux hosts" \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.vendor="Local build" \
      org.opencontainers.image.licenses="MetaTrader-5-and-third-party-terms-apply"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Package versions intentionally follow the current Ubuntu/WineHQ security
# repositories, and WineHQ recommends installing its dependency recommendations.
# hadolint ignore=DL3008,DL3015
RUN if [[ "${TARGETARCH}" != "amd64" ]]; then \
      echo "This image supports amd64 only; received TARGETARCH=${TARGETARCH}" >&2; \
      exit 1; \
    fi \
 && dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && install -d -m 0755 /etc/apt/keyrings \
 && curl --fail --location --silent --show-error \
      https://dl.winehq.org/wine-builds/winehq.key \
      | gpg --dearmor --yes -o /etc/apt/keyrings/winehq-archive.key \
 && curl --fail --location --silent --show-error \
      https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources \
      -o /etc/apt/sources.list.d/winehq-noble.sources \
 && apt-get update \
 && apt-get install -y --install-recommends winehq-staging \
 && apt-get install -y --no-install-recommends \
      cabextract \
      dbus-x11 \
      fonts-dejavu-core \
      fonts-liberation \
      fonts-wine \
      libgl1-mesa-dri \
      novnc \
      openbox \
      procps \
      python3-minimal \
      supervisor \
      tini \
      tzdata \
      websockify \
      winbind \
      x11-utils \
      x11vnc \
      xauth \
      xfonts-base \
      xvfb \
 && rm -rf /var/lib/apt/lists/* \
 && if [[ ! -e /usr/share/novnc/index.html ]]; then \
      ln -s vnc.html /usr/share/novnc/index.html; \
    fi

# Ubuntu 24.04 already has an ubuntu account at UID/GID 1000. Use a high
# default and fail with a useful message if an operator supplies occupied IDs.
RUN if getent group "${TRADER_GID}" >/dev/null; then \
      echo "TRADER_GID=${TRADER_GID} is already in use in the base image; choose an unused GID" >&2; \
      exit 1; \
    fi \
 && if getent passwd "${TRADER_UID}" >/dev/null; then \
      echo "TRADER_UID=${TRADER_UID} is already in use in the base image; choose an unused UID" >&2; \
      exit 1; \
    fi \
 && groupadd --gid "${TRADER_GID}" trader \
 && useradd --uid "${TRADER_UID}" --gid "${TRADER_GID}" \
      --create-home --shell /bin/bash trader \
 && install -d -o trader -g trader /opt/mt5-meta

COPY docker/entrypoint.sh \
     docker/healthcheck.sh \
     docker/install-mt5.sh \
     docker/run-mt5.sh \
     docker/run-novnc.sh \
     docker/run-openbox.sh \
     docker/run-x11vnc.sh \
     docker/run-xvfb.sh \
     /usr/local/bin/
COPY docker/mt5-log-forwarder.py /usr/local/bin/mt5-log-forwarder.py
COPY docker/supervisord.conf /etc/supervisor/conf.d/mt5.conf

RUN chmod 0755 /usr/local/bin/entrypoint.sh \
                 /usr/local/bin/healthcheck.sh \
                 /usr/local/bin/install-mt5.sh \
                 /usr/local/bin/mt5-log-forwarder.py \
                 /usr/local/bin/run-mt5.sh \
                 /usr/local/bin/run-novnc.sh \
                 /usr/local/bin/run-openbox.sh \
                 /usr/local/bin/run-x11vnc.sh \
                 /usr/local/bin/run-xvfb.sh

USER trader
WORKDIR /home/trader

ENV HOME=/home/trader \
    USER=trader \
    DISPLAY=:99 \
    WINEPREFIX=/home/trader/.mt5 \
    WINEARCH=win64 \
    WINEDEBUG=-all \
    WINEDLLOVERRIDES=mscoree,mshtml= \
    LIBGL_ALWAYS_SOFTWARE=1 \
    XDG_CACHE_HOME=/home/trader/.cache \
    XDG_CONFIG_HOME=/tmp/xdg-config \
    XDG_RUNTIME_DIR=/tmp/xdg-runtime

RUN MT5_INSTALLER_URL="${MT5_INSTALLER_URL}" \
    WEBVIEW2_INSTALLER_URL="${WEBVIEW2_INSTALLER_URL}" \
    MT5_INSTALLER_SHA256="${MT5_INSTALLER_SHA256}" \
    WEBVIEW2_INSTALLER_SHA256="${WEBVIEW2_INSTALLER_SHA256}" \
    /usr/local/bin/install-mt5.sh

EXPOSE 6080

# On first use Docker copies this seeded Wine prefix into the named volume.
# Subsequent container replacements reuse the volume, including saved MT5 accounts.
VOLUME ["/home/trader/.mt5"]

HEALTHCHECK --interval=30s --timeout=8s --start-period=180s --retries=3 \
  CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
