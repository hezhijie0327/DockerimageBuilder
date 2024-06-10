# Current Version: 1.0.0

FROM hezhijie0327/base:alpine AS GET_INFO

FROM hezhijie0327/module:binary-nodejs AS BUILD_NODEJS

FROM lobehub/lobe-chat:latest AS BUILD_LOBECHAT

FROM ubuntu:latest AS REBASED_LOBECHAT

COPY --from=GET_INFO /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt

COPY --from=BUILD_NODEJS / /opt/nodejs

COPY --from=BUILD_LOBECHAT /app /opt/lobechat

RUN export LSBCodename=$( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) \
    && rm -rf /etc/apt/sources.list.d/*.* \
    && export OSArchitecture=$( dpkg --print-architecture ) \
    && if [ "${OSArchitecture}" = "amd64" ]; then export MIRROR_URL="ubuntu" ; else export MIRROR_URL="ubuntu-ports" ; fi \
    && echo "deb http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename} main multiverse restricted universe" > "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-backports main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-proposed main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-security main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-updates main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename} main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-backports main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-proposed main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-security main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "deb-src http://mirrors.ustc.edu.cn/${MIRROR_URL} ${LSBCodename}-updates main multiverse restricted universe" >> "/etc/apt/sources.list" \
    && echo "Package: *" > "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-backports" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 990" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" >> "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-security" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 500" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" >> "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-updates" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 500" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" >> "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 500" >> "/etc/apt/preferences" \
    && echo "" >> "/etc/apt/preferences" \
    && echo "Package: *" >> "/etc/apt/preferences" \
    && echo "Pin: release a=${LSBCodename}-proposed" >> "/etc/apt/preferences" \
    && echo "Pin-Priority: 100" >> "/etc/apt/preferences" \
    && apt update \
    && apt full-upgrade -qy \
    && apt autoremove -qy \
    && apt clean autoclean -qy \
    && sed -i 's/http:/https:/g' "/etc/apt/sources.list" \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM scratch

ENV HOSTNAME="0.0.0.0" PORT="3210" \
    ACCESS_CODE="" API_KEY_SELECT_MODE="" \
    ANTHROPIC_API_KEY="" \
    AZURE_API_KEY="" AZURE_API_VERSION="" USE_AZURE_OPENAI="" \
    DEEPSEEK_API_KEY="" \
    GOOGLE_API_KEY="" \
    MINIMAX_API_KEY="" \
    MISTRAL_API_KEY="" \
    MOONSHOT_API_KEY="" \
    OLLAMA_PROXY_URL="" OLLAMA_MODEL_LIST="" \
    OPENAI_PROXY_URL="" OPENAI_API_KEY="" OPENAI_MODEL_LIST="" \
    OPENROUTER_API_KEY="" OPENROUTER_MODEL_LIST="" \
    PERPLEXITY_API_KEY="" \
    QWEN_API_KEY="" \
    TOGETHERAI_API_KEY="" \
    ZEROONE_API_KEY="" \
    ZHIPU_API_KEY=""

COPY --from=REBASED_LOBECHAT / /

EXPOSE 3210/tcp

CMD ["/opt/nodejs/bin/node", "/opt/lobechat/server.js"]
