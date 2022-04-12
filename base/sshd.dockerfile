# Current Version: 1.0.0

FROM alpine:latest

RUN echo root:${ROOT_PASSWORD:-R00t@123!} | chpasswd && apk update && apk upgrade && apk add openssh && ssh-keygen -t dsa -b 1024 -f "/etc/ssh/ssh_host_dsa_key" -N "" && ssh-keygen -t ecdsa -b 384 -f "/etc/ssh/ssh_host_ecdsa_key" -N "" && ssh-keygen -t ed25519 -f "/etc/ssh/ssh_host_ed25519_key" -N "" && ssh-keygen -t rsa -b 4096 -f "/etc/ssh/ssh_host_rsa_key" -N "" && chmod 400 /etc/ssh/ssh_host_*_key && chmod 644 /etc/ssh/ssh_host_*.pub && chmod 700 "/etc/ssh" && sed -i "s/\#PasswordAuthentication\ yes/PasswordAuthentication\ yes/g;s/\#PermitRootLogin\ prohibit\-password/PermitRootLogin\ yes/g;s/\#PubkeyAuthentication\ yes/PubkeyAuthentication\ yes/g" "/etc/ssh/sshd_config" && sed -i "s/dl-cdn.alpinelinux.org/mirrors.ustc.edu.cn/g" "/etc/apk/repositories" && rm -rf /tmp/* /var/cache/apk/*

EXPOSE 22/tcp

CMD ["/usr/sbin/sshd", "-D"]
