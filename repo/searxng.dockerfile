# Current Version: 1.1.4

FROM searxng/searxng:latest AS BUILD_SEARXNG

RUN sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" \
    && apk update \
    && apk upgrade --no-cache \
    && rm -rf /tmp/* /var/cache/apk/*

FROM scratch

COPY --from=BUILD_SEARXNG / /

ENV BIND_ADDRESS="0.0.0.0:8081" SEARXNG_SETTINGS_PATH="/etc/searxng/settings.yml" UWSGI_SETTINGS_PATH="/etc/searxng/uwsgi.ini" UWSGI_WORKERS="%k" UWSGI_THREADS="4"

EXPOSE 8081/tcp

ENTRYPOINT ["/sbin/tini","--","/usr/local/searxng/dockerfiles/docker-entrypoint.sh"]
