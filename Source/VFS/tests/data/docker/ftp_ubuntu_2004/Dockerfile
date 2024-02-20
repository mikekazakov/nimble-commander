FROM ubuntu:20.04

RUN apt-get update && \
  apt-get install -y --no-install-recommends vsftpd db-util && \
  apt-get clean

ENV FTP_USER ftpuser
ENV FTP_PASS ftpuserpasswd
ENV PASV_ADDRESS 127.0.0.1

COPY vsftpd.conf /etc/vsftpd/
COPY vsftpd_virtual /etc/pam.d/
COPY run-vsftpd.sh /usr/sbin/

RUN chmod +x /usr/sbin/run-vsftpd.sh && \
 mkdir -p /var/run/vsftpd/empty

VOLUME /home/vsftpd
VOLUME /var/log/vsftpd

EXPOSE 20 21

CMD ["/usr/sbin/run-vsftpd.sh"]
