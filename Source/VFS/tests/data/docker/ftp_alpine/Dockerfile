FROM alpine:3.21

RUN apk add --no-cache vsftpd

ENV FTP_USER ftpuser
ENV FTP_PASS ftpuserpasswd
ENV PASV_ADDRESS 127.0.0.1

COPY vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY vsftpd_pam /etc/pam.d/vsftpd
COPY run-vsftpd.sh /usr/sbin/run-vsftpd.sh

RUN chmod +x /usr/sbin/run-vsftpd.sh && \
    mkdir -p /var/run/vsftpd/empty

VOLUME /home/vsftpd
VOLUME /var/log/vsftpd

EXPOSE 20 21

CMD ["/usr/sbin/run-vsftpd.sh"]
