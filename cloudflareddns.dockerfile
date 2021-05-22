# Current Version: 1.0.0

FROM alpine:latest

WORKDIR /etc

RUN apk --update --no-cache add curl jq && mkdir "/etc/CloudflareDDNS" && ln -s "/etc/CloudflareDDNS" "/opt/cloudflareddns" && curl -s --connect-timeout 15 "https://raw.githubusercontent.com/hezhijie0327/CloudflareDDNS/main/CloudflareDDNS.sh" > "/etc/CloudflareDDNS/CloudflareDDNS.sh" && rm -rf /tmp/*

WORKDIR /opt/cloudflareddns

ENV XAUTHEMAIL=${XAUTHEMAIL} XAUTHKEY=${XAUTHKEY} ZONENAME=${ZONENAME} RECORDNAME=${RECORDNAME} TYPE=${TYPE} TTL=${TTL} PROXYSTATUS=${PROXYSTATUS} RUNNINGMODE=${RUNNINGMODE} UPDATEFREQUENCY=${UPDATEFREQUENCY}

CMD [ "sh", "-c", "sh '/etc/CloudflareDDNS/CloudflareDDNS.sh' -e ${XAUTHEMAIL:-demo@zhijie.online} -k ${XAUTHKEY:-123defghijk4567pqrstuvw890} -z ${ZONENAME:-zhijie.online} -r ${RECORDNAME:-demo.zhijie.online} -t ${TYPE:-A} -l ${TTL:-3600} -p ${PROXYSTATUS:-false} -m ${RUNNINGMODE:-update} && sleep ${UPDATEFREQUENCY:-3600}" ]
