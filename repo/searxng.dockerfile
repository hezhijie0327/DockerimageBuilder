# Current Version: 1.2.1

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

FROM python:${PYTHON_VERSION}-alpine AS build_searxng

WORKDIR /usr/local/searxng

COPY --from=get_info /tmp/BUILDTMP/SEARXNG/requirements.txt /usr/local/searxng/requirements.txt
COPY --from=get_info /tmp/BUILDTMP/SEARXNG/searx /usr/local/searxng/searx

RUN \
    apk update \
    && apk upgrade --no-cache \
    && apk add --no-cache -t build-dependencies \
        brotli \
        build-base \
        git \
        openssl \
        openblas openblas-dev gfortran cmake pkgconfig linux-headers \
    && pip install --no-cache --break-system-packages -r requirements.txt \
    && python3 -m compileall -q searx \
    && find searx/static -a \( -name '*.html' -o -name '*.css' -o -name '*.js' \
        -o -name '*.svg' -o -name '*.ttf' -o -name '*.eot' \) \
        -type f -exec gzip -9 -k {} \+ -exec brotli --best {} \+ \
    && apk del --purge build-dependencies \
    && apk del --purge alpine* > /dev/null || true \
    && apk add --no-cache busybox \
    && apk del --purge apk* > /dev/null || true \
    && /bin/busybox --install -s /bin \
    && rm -rf /etc /lib/*apk* /root/* /sbin /usr/sbin /usr/share /var || true \
    && rm -rf /root/* /tmp/* /var/cache/apk/*

FROM busybox:musl AS rebased_searxng

COPY --from=get_info /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=build_searxng /lib /lib
COPY --from=build_searxng /usr/lib /usr/lib
COPY --from=build_searxng /usr/local /usr/local

FROM scratch

ENV \
    PYTHONPATH="/usr/local/searxng" \
    SEARXNG_SETTINGS_PATH="/usr/local/searxng/searx/settings.yml"

COPY --from=rebased_searxng / /

EXPOSE 8888/tcp

ENTRYPOINT ["/usr/local/bin/python"]

CMD ["/usr/local/searxng/searx/webapp.py"]
