FROM alpine:3.21

RUN apk add --no-cache lighttpd lighttpd-mod_auth lighttpd-mod_webdav apache2-utils && \
    mkdir -p /var/www/webdav && \
    chown lighttpd:lighttpd /var/www/webdav && \
    htpasswd -cb /etc/lighttpd/.htpasswd r2d2 Hello

COPY lighttpd.conf /etc/lighttpd/lighttpd.conf

EXPOSE 80

CMD ["lighttpd", "-D", "-f", "/etc/lighttpd/lighttpd.conf"]
