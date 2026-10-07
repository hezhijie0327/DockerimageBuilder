ARG NODEJS_VERSION="24"
ARG PYTHON_VERSION="3"

FROM ghcr.io/hezhijie0327/base:alpine AS get_info

WORKDIR /tmp

RUN \
    export WORKDIR=$(pwd) \
    && cat "/opt/package.json" | jq -Sr ".repo.searxng" > "${WORKDIR}/searxng.json" \
    && cat "${WORKDIR}/searxng.json" | jq -Sr ".version" \
    && cat "${WORKDIR}/searxng.json" | jq -Sr ".source" > "${WORKDIR}/searxng.source.autobuild" \
    && cat "${WORKDIR}/searxng.json" | jq -Sr ".source_branch" > "${WORKDIR}/searxng.source_branch.autobuild" \
    && cat "${WORKDIR}/searxng.json" | jq -Sr ".patch" > "${WORKDIR}/searxng.patch.autobuild" \
    && cat "${WORKDIR}/searxng.json" | jq -Sr ".patch_branch" > "${WORKDIR}/searxng.patch_branch.autobuild" \
    && cat "${WORKDIR}/searxng.json" | jq -Sr ".version" > "${WORKDIR}/searxng.version.autobuild" \
    && git clone -b $(cat "${WORKDIR}/searxng.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/searxng.source.autobuild") "${WORKDIR}/BUILDTMP/SEARXNG" \
    && git clone -b "zjsearch" --depth=1 "https://github.com/hezhijie0327/ZJSearch.git" "${WORKDIR}/BUILDTMP/ZJSEARCH" \
    && git clone -b $(cat "${WORKDIR}/searxng.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/searxng.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export SEARXNG_SHA=$(cd "${WORKDIR}/BUILDTMP/SEARXNG" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export SEARXNG_VERSION=$(date '+%Y.%m.%d') \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export SEARXNG_CUSTOM_VERSION="${SEARXNG_VERSION}-ZHIJIE-${SEARXNG_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/ZJSEARCH" \
    && bash ./client/zjsearch/make-patch.sh \
    && cd "${WORKDIR}/BUILDTMP/SEARXNG" \
    && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/searxng/*.patch \
    && git apply --reject ${WORKDIR}/BUILDTMP/ZJSEARCH/*.patch \
    && sed -i "s|ultrasecretkey|$(openssl rand -hex 32)|g;s|127.0.0.1|0.0.0.0|g" "${WORKDIR}/BUILDTMP/SEARXNG/searx/settings.yml" \
    && sed -i "s|VERSION_STRING: str = \"1.0.0\"|VERSION_STRING: str = \"${SEARXNG_CUSTOM_VERSION}\"|g;s|GIT_URL = \"unknow\"|GIT_URL = \"https://github.com/searxng/searxng\"|g" "${WORKDIR}/BUILDTMP/SEARXNG/searx/version.py"

FROM node:${NODEJS_VERSION}-slim AS build_searxng_frontend

WORKDIR /app

COPY --from=get_info /tmp/BUILDTMP/SEARXNG/client/simple /app/client/simple
COPY --from=get_info /tmp/BUILDTMP/SEARXNG/client/zjsearch /app/client/zjsearch
COPY --from=get_info /tmp/BUILDTMP/SEARXNG/requirements.txt /app/requirements.txt
COPY --from=get_info /tmp/BUILDTMP/SEARXNG/searx /app/searx
COPY --from=get_info /tmp/BUILDTMP/SEARXNG/LICENSE /app/LICENSE

WORKDIR /app/client/simple

RUN \
    npm i \
    && npm run build

WORKDIR /app/client/zjsearch

RUN \
    npm i -g corepack@latest \
    && corepack enable \
    && corepack use $(sed -n 's/.*"packageManager": "\(.*\)".*/\1/p' package.json) \
    && pnpm i \
    && pnpm run build

FROM python:${PYTHON_VERSION}-slim AS build_searxng

WORKDIR /app

COPY --from=build_searxng_frontend /app/requirements.txt /app/requirements.txt
COPY --from=build_searxng_frontend /app/searx /app/searx

RUN \
    apt update \
    && apt install -qy \
        brotli \
        build-essential \
        git \
        openssl \
        cmake gfortran libopenblas-dev pkg-config \
        # indexed-zstd (a camoufox dependency) builds from source when the
        # platform/python lacks a wheel -- it needs the zstd headers
        libzstd-dev \
    && python3 -m venv /app \
    && . /app/bin/activate \
    && pip install --no-cache -r requirements.txt \
    && pip install --no-cache \
        tzdata \
    # the built-in render engine's browser bundle (zjsearch.browser):
    # XDG_CACHE_HOME pins the camoufox install into /app so the final
    # stage ships it together with the venv (the runtime ENV re-exports
    # the same path)
    && XDG_CACHE_HOME=/app/browser-cache python3 -m searx.zjsearch.ai.browser.install \
    && python3 -m compileall -q searx \
    && find searx/static \( -name '*.html' -o -name '*.css' -o -name '*.js' \
        -o -name '*.svg' -o -name '*.ttf' -o -name '*.eot' \) \
        -type f -exec gzip -9 -k {} \+ -exec brotli --best {} \+ \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

# browserless-style system fonts: camoufox's bundled font library (~2.1 GB
# of fingerprint-font sets) is deleted entirely, and its per-OS fontconfig
# template gains /usr/share/fonts as a scan dir -- the pages then resolve
# the apt font packages the dist stage installs.  The fingerprint is pinned
# to linux (zjsearch.browser.os), so the system set IS the identity's font
# list.  The template lives at fontconfig/<os>/fonts.conf; camoufox rewrites
# its <dir prefix="cwd">fonts</dir> marker at launch -- the appended line
# survives that rewrite.
RUN rm -rf /app/browser-cache/camoufox/browsers/*/*/fonts \
    && sed -i 's|<dir prefix="cwd">fonts</dir>|<dir prefix="cwd">fonts</dir><dir>/usr/share/fonts</dir>|' \
        /app/browser-cache/camoufox/browsers/*/*/fontconfig/linux/fonts.conf

FROM python:${PYTHON_VERSION}-slim

# the built-in browser's runtime: Xvfb (zjsearch.browser.mode: virtual) and
# the Firefox/GTK library set with fonts -- the SAME base image the venv was
# built on, so nothing needs hand-copying out of a distroless assembly
RUN \
    sed -i "s|main|main contrib non-free non-free-firmware|g;s/stable/${LSBCodename:-stable}/g" "/etc/apt/sources.list.d/debian.sources" \
    && echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections \
    && apt update \
    && apt install -qy --no-install-recommends \
        xvfb \
        libgtk-3-0 \
        libdbus-glib-1-2 \
        libxt6 \
        libasound2 \
        libx11-xcb1 libxcb1 \
        libxcomposite1 libxdamage1 libxext6 libxfixes3 libxrandr2 \
        libxkbcommon0 libgbm1 libdrm2 \
        fontconfig \
        fonts-freefont-ttf \
        fonts-gfs-neohellenic \
        fonts-indic \
        fonts-ipafont-gothic \
        fonts-kacst-one \
        fonts-liberation \
        fonts-noto-cjk \
        fonts-noto-color-emoji \
        fonts-roboto \
        fonts-thai-tlwg \
        fonts-ubuntu \
        fonts-wqy-zenhei \
        fonts-open-sans \
        ttf-mscorefonts-installer \
    && fc-cache -f \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build_searxng /app /app

COPY --from=build_searxng /app/searx/settings.yml /app/searx/limiter.toml /app/searx/favicons/favicons.toml /config/

ENV \
    PYTHONPATH="/app" \
    SEARXNG_SETTINGS_PATH="/config/settings.yml" \
    XDG_CACHE_HOME="/app/browser-cache"

EXPOSE 8888/tcp

ENTRYPOINT ["/app/bin/python"]

CMD ["-m", "searx.webapp"]
