# Current Version: 1.0.0

FROM alpine:latest

RUN apk --update --no-cache add py3-pip python3 && apk --update --no-cache add --virtual development-env cargo g++ gcc libffi-dev mysql-dev openssl-dev python3-dev rust && mkdir "/etc/letsencrypt" "/var/lib/letsencrypt" && ln -s "/var/lib/letsencrypt" "/etc/letsencrypt/lib" && ln -s "/etc/letsencrypt" "/opt/certbot" && pip3 --no-cache-dir install certbot certbot-dns-cloudflare certbot-dns-cloudxns certbot-dns-digitalocean certbot-dns-dnsimple certbot-dns-dnsmadeeasy certbot-dns-gehirn certbot-dns-google certbot-dns-linode certbot-dns-luadns certbot-dns-nsone certbot-dns-ovh certbot-dns-rfc2136 certbot-dns-route53 certbot-dns-sakuracloud && certbot --version && apk del development-env && rm -rf /tmp/* .cache/pip

WORKDIR /opt/certbot

VOLUME ["/opt/certbot"]

ENTRYPOINT ["/usr/bin/certbot"]
