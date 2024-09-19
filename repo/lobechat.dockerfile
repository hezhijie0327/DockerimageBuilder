# Current Version: 1.6.7

FROM hezhijie0327/base:alpine AS GET_INFO

WORKDIR /tmp

RUN export WORKDIR=$(pwd) && cat "/opt/package.json" | jq -Sr ".repo.lobechat" > "${WORKDIR}/lobechat.json" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".version" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".source" > "${WORKDIR}/lobechat.source.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".source_branch" > "${WORKDIR}/lobechat.source_branch.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".patch" > "${WORKDIR}/lobechat.patch.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".patch_branch" > "${WORKDIR}/lobechat.patch_branch.autobuild" && cat "${WORKDIR}/lobechat.json" | jq -Sr ".version" > "${WORKDIR}/lobechat.version.autobuild"

FROM --platform=linux/amd64 hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM --platform=linux/amd64 hezhijie0327/base:ubuntu AS BUILD_LOBECHAT

WORKDIR /tmp

COPY --from=GET_INFO /tmp/lobechat.*.autobuild /tmp/

COPY --from=BUILD_NODEJS / /tmp/BUILDLIB/

RUN export WORKDIR=$(pwd) && mkdir -p "${WORKDIR}/BUILDTMP" && export PREFIX="${WORKDIR}/BUILDLIB" && export PNPM_HOME="/pnpm" && export PATH="${PNPM_HOME}:${PREFIX}/bin:${PATH}" && git clone -b $(cat "${WORKDIR}/lobechat.source_branch.autobuild") --depth=1 $(cat "${WORKDIR}/lobechat.source.autobuild") "${WORKDIR}/BUILDTMP/LOBECHAT" && git clone -b $(cat "${WORKDIR}/lobechat.patch_branch.autobuild") --depth=1 $(cat "${WORKDIR}/lobechat.patch.autobuild") "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && export LOBECHAT_SHA=$(cd "${WORKDIR}/BUILDTMP/LOBECHAT" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export LOBECHAT_VERSION=$(cat "${WORKDIR}/lobechat.version.autobuild") && export PATCH_SHA=$(cd "${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER" && git rev-parse --short HEAD | cut -c 1-4 | tr "a-z" "A-Z") && export LOBECHAT_CUSTOM_VERSION="${LOBECHAT_VERSION}-ZHIJIE-${LOBECHAT_SHA}${PATCH_SHA}" && cd "${WORKDIR}/BUILDTMP/LOBECHAT" && git apply --reject ${WORKDIR}/BUILDTMP/DOCKERIMAGEBUILDER/patch/lobechat/*.patch && sed -i "s/\"version\": \"[0-9]\+\.[0-9]\+\.[0-9]\+\"/\"version\": \"${LOBECHAT_CUSTOM_VERSION}\"/g" "${WORKDIR}/BUILDTMP/LOBECHAT/package.json" && corepack enable && corepack use pnpm && pnpm i && mkdir -p "${WORKDIR}/BUILDTMP/LOBECHAT/sharp" && pnpm add sharp --prefix "${WORKDIR}/BUILDTMP/LOBECHAT/sharp" && npm run build:docker

FROM node:lts-slim AS BUILD_BASEOS

ENV DEBIAN_FRONTEND="noninteractive"

RUN sed -i "s/deb.debian.org/mirrors.ustc.edu.cn/g" "/etc/apt/sources.list.d/debian.sources" \
    && apt update \
    && apt install proxychains-ng -qy \
    && mkdir -p /distroless/bin /distroless/lib /distroless/etc/ssl/certs \
    && cp /usr/lib/$(arch)-linux-gnu/libproxychains.so.4 /distroless/lib/libproxychains.so.4 \
    && cp /usr/lib/$(arch)-linux-gnu/libdl.so.2 /distroless/lib/libdl.so.2 \
    && cp /usr/bin/proxychains4 /distroless/bin/proxychains \
    && cp /etc/proxychains4.conf /distroless/etc/proxychains4.conf \
    && cp /usr/lib/$(arch)-linux-gnu/libstdc++.so.6 /distroless/lib/libstdc++.so.6 \
    && cp /usr/lib/$(arch)-linux-gnu/libgcc_s.so.1 /distroless/lib/libgcc_s.so.1 \
    && cp /usr/local/bin/node /distroless/bin/node \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM busybox:latest AS REBASED_LOBECHAT

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=BUILD_BASEOS /distroless/ /

COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/.next/standalone /app
COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/.next/static /app/.next/static

COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/public /app/public

COPY --from=BUILD_LOBECHAT /tmp/BUILDTMP/LOBECHAT/sharp/node_modules/.pnpm /app/node_modules/.pnpm

RUN \
    # Add nextjs:nodejs to run the app
    addgroup -S -g 1001 nodejs \
    && adduser -D -G nodejs -H -S -h /app -u 1001 nextjs \
    # Set permission for nextjs:nodejs
    && chown -R nextjs:nodejs /app /etc/proxychains4.conf

FROM scratch

ENV NODE_ENV="production" NODE_TLS_REJECT_UNAUTHORIZED="1" \
    FEATURE_FLAGS="-check_updates,-welcome_suggest" \
    HOSTNAME="0.0.0.0" PORT="3210"

COPY --from=REBASED_LOBECHAT / /

USER nextjs

EXPOSE 3210/tcp

CMD \
    if [ -n "$PROXY_URL" ]; then \
        # Set regex for IPv4
        IP_REGEX="^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}$"; \
        # Set proxychains command
        PROXYCHAINS="proxychains -q"; \
        # Parse the proxy URL
        host_with_port="${PROXY_URL#*//}"; \
        host="${host_with_port%%:*}"; \
        port="${PROXY_URL##*:}"; \
        protocol="${PROXY_URL%%://*}"; \
        # Resolve to IP address if the host is a domain
        if ! [[ "$host" =~ "$IP_REGEX" ]]; then \
            nslookup=$(nslookup -q="A" "$host" | tail -n +3 | grep 'Address:'); \
            if [ -n "$nslookup" ]; then \
                host=$(echo "$nslookup" | tail -n 1 | awk '{print $2}'); \
            fi; \
        fi; \
        # Generate proxychains configuration file
        printf "%s\n" \
            'localnet 127.0.0.0/255.0.0.0' \
            'localnet ::1/128' \
            'proxy_dns' \
            'remote_dns_subnet 224' \
            'strict_chain' \
            'tcp_connect_time_out 8000' \
            'tcp_read_time_out 15000' \
            '[ProxyList]' \
            "$protocol $host $port" \
        > "/etc/proxychains4.conf"; \
    fi; \
    # Run the server
    ${PROXYCHAINS} node "/app/server.js";
