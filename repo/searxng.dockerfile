# Current Version: 1.2.7

ARG PYTHON_VERSION="3"

FROM hezhijie0327/module:alpine AS get_info

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
    && git clone -b $(cat "${WORKDIR}/searxng.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/searxng.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" \
    && export SEARXNG_SHA=$(cd "${WORKDIR}/BUILDTMP/SEARXNG" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export SEARXNG_VERSION=$(cat "${WORKDIR}/searxng.version.autobuild") \
    && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") \
    && export SEARXNG_CUSTOM_VERSION="${SEARXNG_VERSION}-ZHIJIE-${SEARXNG_SHA}${PATCH_SHA}" \
    && cd "${WORKDIR}/BUILDTMP/SEARXNG" \
    && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/searxng/*.patch \
    && sed -i "s|ultrasecretkey|$(openssl rand -hex 32)|g;s|127.0.0.1|0.0.0.0|g" "${WORKDIR}/BUILDTMP/SEARXNG/searx/settings.yml" \
    && sed -i "s|VERSION_STRING = \"1.0.0\"|VERSION_STRING = \"${SEARXNG_CUSTOM_VERSION}\"|g;s|GIT_URL = \"unknow\"|GIT_URL = \"https://github.com/searxng/searxng\"|g" "${WORKDIR}/BUILDTMP/SEARXNG/searx/version.py"

FROM python:${PYTHON_VERSION}-slim AS build_searxng

WORKDIR /app

COPY --from=get_info /tmp/BUILDTMP/SEARXNG/requirements.txt /app/requirements.txt
COPY --from=get_info /tmp/BUILDTMP/SEARXNG/searx /app/searx

RUN \
    apt update \
    && apt install -qy \
        brotli \
        build-essential \
        git \
        openssl \
        cmake gfortran libopenblas-dev pkg-config \
    && python3 -m venv /app \
    && . /app/bin/activate \
    && pip install --no-cache -r requirements.txt \
    && python3 -m compileall -q searx \
    && find searx/static \( -name '*.html' -o -name '*.css' -o -name '*.js' \
        -o -name '*.svg' -o -name '*.ttf' -o -name '*.eot' \) \
        -type f -exec gzip -9 -k {} \+ -exec brotli --best {} \+ \
    && mkdir -p /distroless/lib /distroless/usr/local/bin \
    && cp /usr/local/bin/python3 /distroless/usr/local/bin/python3 \
    && cp /usr/local/bin/python3-config /distroless/usr/local/bin/python3-config \
    && cp -rf /usr/local/include /distroless/usr/local/include \
    && cp -rf /usr/local/lib /distroless/usr/local/lib \
    && cp /usr/lib/$(arch)-linux-gnu/libcrypto.so.3 /distroless/lib/libcrypto.so.3 \
    && cp /usr/lib/$(arch)-linux-gnu/libffi.so.8 /distroless/lib/libffi.so.8 \
    && cp /usr/lib/$(arch)-linux-gnu/libgcc_s.so.1 /distroless/lib/libgcc_s.so.1 \
    && cp /usr/lib/$(arch)-linux-gnu/librt.so.1 /distroless/lib/librt.so.1 \
    && cp /usr/lib/$(arch)-linux-gnu/libsqlite3.so.0 /distroless/lib/libsqlite3.so.0 \
    && cp /usr/lib/$(arch)-linux-gnu/libssl.so.3 /distroless/lib/libssl.so.3 \
    && cp /usr/lib/$(arch)-linux-gnu/libstdc++.so.6 /distroless/lib/libstdc++.so.6 \
    && cp /usr/lib/$(arch)-linux-gnu/libz.so.1 /distroless/lib/libz.so.1 \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM busybox:latest AS rebased_searxng

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_searxng /distroless /

COPY --from=build_searxng /app /app

FROM scratch

ENV \
    PYTHONPATH="/app" \
    SEARXNG_SETTINGS_PATH="/app/searx/settings.yml"

COPY --from=rebased_searxng / /

EXPOSE 8888/tcp

ENTRYPOINT ["/app/bin/python"]

CMD ["-m", "searx.webapp"]
