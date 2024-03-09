# Current Version: 1.0.2

FROM hezhijie0327/base:alpine AS GET_INFO

ADD ../patch/package.json /tmp/package.json

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "${WORKDIR}/package.json" | jq -Sr ".repo.morty" > "${WORKDIR}/morty.json" && cat "${WORKDIR}/morty.json" | jq -Sr ".version" && cat "${WORKDIR}/morty.json" | jq -Sr ".source" > "${WORKDIR}/morty.source.autobuild" && cat "${WORKDIR}/morty.json" | jq -Sr ".source_branch" > "${WORKDIR}/morty.source_branch.autobuild" && cat "${WORKDIR}/morty.json" | jq -Sr ".patch" > "${WORKDIR}/morty.patch.autobuild" && cat "${WORKDIR}/morty.json" | jq -Sr ".patch_branch" > "${WORKDIR}/morty.patch_branch.autobuild" && cat "${WORKDIR}/morty.json" | jq -Sr ".version" > "${WORKDIR}/morty.version.autobuild"

FROM hezhijie0327/module:binary-golang AS BUILD_GOLANG

FROM hezhijie0327/base:ubuntu AS BUILD_MORTY

WORKDIR /tmp

COPY --from=GET_INFO /tmp/morty.*.autobuild /tmp/

COPY --from=BUILD_GOLANG / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDKIT" "${WORKDIR}/BUILDTMP" "${WORKDIR}/BUILDKIT/etc/ssl/certs" && cp -rf "/etc/ssl/certs/ca-certificates.crt" "${WORKDIR}/BUILDKIT/etc/ssl/certs/ca-certificates.crt" && export PREFIX="${WORKDIR}/BUILDLIB" && export PATH="${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/morty.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/morty.source.autobuild") "${WORKDIR}/BUILDTMP/MORTY" && git clone -b $(cat "${WORKDIR}/morty.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/morty.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export MORTY_SHA=$(cd "${WORKDIR}/BUILDTMP/MORTY" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export MORTY_VERSION=$(cat "${WORKDIR}/BUILDTMP/MORTY/morty.go" | grep "const VERSION" | cut -d " " -f 4 | tr -d '[a-z]"') && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export MORTY_CUSTOM_VERSION="${MORTY_VERSION}-ZHIJIE-${MORTY_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/MORTY" && sed -i "s/${MORTY_VERSION}/${MORTY_CUSTOM_VERSION}/g" "${WORKDIR}/BUILDTMP/MORTY/morty.go" && go get -d -v && gofmt -l ./ && export CGO_ENABLED=0 && go build . && cp -rf "${WORKDIR}/BUILDTMP/MORTY/morty" "${WORKDIR}/BUILDKIT/morty"

FROM hezhijie0327/gpg:latest AS GPG_SIGN

COPY --from=BUILD_MORTY /tmp/BUILDKIT /tmp/BUILDKIT/

RUN gpg --detach-sign --passphrase "$(cat '/root/.gnupg/ed25519_passphrase.key' | base64 -d)" --pinentry-mode "loopback" "/tmp/BUILDKIT/morty"

FROM searxng/searxng:latest AS BUILD_SEARXNG

COPY --from=GPG_SIGN /tmp/BUILDKIT/etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=GPG_SIGN /tmp/BUILDKIT/morty /usr/local/morty/morty
COPY --from=GPG_SIGN /tmp/BUILDKIT/morty.sig /usr/local/morty/morty.sig

RUN sed -i "s|unset MORTY_KEY|unset MORTY_KEY\ncd /usr/local/searxng\n/usr/local/morty/morty -followredirect true -ipv6 true -proxyenv -timeout 5 \&|g" "/usr/local/searxng/dockerfiles/docker-entrypoint.sh" && export MORTY_VERSION=$("/usr/local/morty/morty" -version | cut -d '-' -f 3) && export SEARXNG_VERSION=$(cat "/usr/local/searxng/searx/version_frozen.py" | grep 'VERSION_STRING' | cut -d '=' -f 2 | cut -d '"' -f 2) && sed -i "s|${SEARXNG_VERSION}|${SEARXNG_VERSION}-ZHIJIE-${MORTY_VERSION}|g" "/usr/local/searxng/searx/version_frozen.py"

FROM scratch

COPY --from=BUILD_SEARXNG / /

ENV BIND_ADDRESS="0.0.0.0:8081" MORTY_ADDRESS="0.0.0.0:8082" MORTY_KEY="" SEARXNG_SETTINGS_PATH="/etc/searxng/settings.yml" UWSGI_SETTINGS_PATH="/etc/searxng/uwsgi.ini" UWSGI_WORKERS="%k" UWSGI_THREADS="4"

EXPOSE 8081/tcp 8082/tcp

ENTRYPOINT ["/sbin/tini","--","/usr/local/searxng/dockerfiles/docker-entrypoint.sh"]
