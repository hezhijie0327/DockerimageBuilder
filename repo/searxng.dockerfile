# Current Version: 1.0.3

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".repo.searxng" > "${WORKDIR}/searxng.json" && cat "${WORKDIR}/searxng.json" | jq -Sr ".version" && cat "${WORKDIR}/searxng.json" | jq -Sr ".source" > "${WORKDIR}/searxng.source.autobuild" && cat "${WORKDIR}/searxng.json" | jq -Sr ".source_branch" > "${WORKDIR}/searxng.source_branch.autobuild" && cat "${WORKDIR}/searxng.json" | jq -Sr ".patch" > "${WORKDIR}/searxng.patch.autobuild" && cat "${WORKDIR}/searxng.json" | jq -Sr ".patch_branch" > "${WORKDIR}/searxng.patch_branch.autobuild" && cat "${WORKDIR}/searxng.json" | jq -Sr ".version" > "${WORKDIR}/searxng.version.autobuild"

FROM alpine:latest AS BUILD_SEARXNG

WORKDIR /tmp

COPY --from=GET_INFO /tmp/searxng.*.autobuild /tmp/

RUN sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" \
    && apk update \
    && apk upgrade --no-cache \
    && apk add --no-cache -t build-dependencies \
        build-base \
        py3-setuptools \
        python3-dev \
        libffi-dev \
        libxslt-dev \
        libxml2-dev \
        openssl-dev \
        tar \
        git \
    && apk add --no-cache \
        ca-certificates \
        python3 \
        py3-pip \
        libxml2 \
        libxslt \
        openssl \
        tini \
        uwsgi \
        uwsgi-python3 \
        brotli \
    && export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDTMP" "/usr/local/searxng" && git clone -b $(cat "${WORKDIR}/searxng.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/searxng.source.autobuild") "${WORKDIR}/BUILDTMP/SEARXNG" && git clone -b $(cat "${WORKDIR}/searxng.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/searxng.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export SEARXNG_SHA=$(cd "${WORKDIR}/BUILDTMP/SEARXNG" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export SEARXNG_VERSION=$(cat "${WORKDIR}/searxng.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export SEARXNG_CUSTOM_VERSION="${SEARXNG_VERSION}-ZHIJIE-${SEARXNG_SHA}${PATCH_SHA}" \
    && cp -rf "${WORKDIR}/BUILDTMP/SEARXNG/requirements.txt" "/usr/local/searxng/requirements.txt" \
    && cp -rf "${WORKDIR}/BUILDTMP/SEARXNG/dockerfiles" "/usr/local/searxng/dockerfiles" \
    && cp -rf "${WORKDIR}/BUILDTMP/SEARXNG/searx" "/usr/local/searxng/searx" \
    && sed -i 's|gid = searxng|gid = root|g;s|uid = searxng|uid = root|g' "/usr/local/searxng/dockerfiles/uwsgi.ini" \
    && sed -i "s|VERSION_STRING = \"1.0.0\"|VERSION_STRING = \"${SEARXNG_CUSTOM_VERSION}\"|g;s|GIT_URL = \"unknow\"|GIT_URL = \"https://github.com/searxng/searxng\"|g" "/usr/local/searxng/searx/version.py" \
    && cd "/usr/local/searxng" \
    && pip config set global.index-url https://mirrors.ustc.edu.cn/pypi/simple \
    && pip install --no-cache --break-system-packages -r requirements.txt \
    && apk del build-dependencies \
    && rm -rf /tmp/* /var/cache/apk/* \
    && python3 -m compileall -q searx \
    && find /usr/local/searxng/searx/static -a \( -name '*.html' -o -name '*.css' -o -name '*.js' \
        -o -name '*.svg' -o -name '*.ttf' -o -name '*.eot' \) \
        -type f -exec gzip -9 -k {} \+ -exec brotli --best {} \+

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

FROM scratch

ENV BIND_ADDRESS="0.0.0.0:8080" \
    SEARXNG_SETTINGS_PATH="/etc/searxng/settings.yml" \
    UWSGI_SETTINGS_PATH="/etc/searxng/uwsgi.ini" \
    UWSGI_THREADS="4" \
    UWSGI_WORKERS="%k"

COPY --from=BUILD_SEARXNG / /

EXPOSE 8080/tcp

ENTRYPOINT ["/sbin/tini","--","/usr/local/searxng/dockerfiles/docker-entrypoint.sh"]
