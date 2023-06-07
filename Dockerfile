FROM --platform=linux/amd64 nginx

ENV CERTBOT_ALB_NAME="" \
    CERTBOT_CERT_PATH="/etc/letsencrypt/live" \
    CERTBOT_DOMAINS="" \
    CERTBOT_EMAIL="" \
    CERTBOT_ENABLED=false \
    DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y certbot cron jq less unzip && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip -u awscliv2.zip && ./aws/install

COPY *.sh /root
COPY default.conf /etc/nginx/conf.d/default.conf

ENTRYPOINT ["/root/entrypoint-wrapper.sh"]
CMD ["nginx", "-g", "daemon off;"]
