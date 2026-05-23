#!/bin/sh

# Create home dir and log dir:
mkdir -p /home/vsftpd
mkdir -p /var/log/vsftpd

# Create the FTP user with the home dir as its home directory:
adduser -D -h /home/vsftpd -s /sbin/nologin "${FTP_USER}" 2>/dev/null || true
echo "${FTP_USER}:${FTP_PASS}" | chpasswd
chown -R "${FTP_USER}:${FTP_USER}" /home/vsftpd

# Set passive mode parameters:
if [ "$PASV_ADDRESS" = "REQUIRED" ]; then
    echo "Please insert IPv4 address of your host"
    exit 1
fi
echo "pasv_address=${PASV_ADDRESS}" >> /etc/vsftpd/vsftpd.conf

# Run vsftpd:
vsftpd /etc/vsftpd/vsftpd.conf
