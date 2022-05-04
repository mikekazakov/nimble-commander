#!/bin/sh

docker build \
    --tag sftp_ubuntu_2004:v1 \
    sftp_ubuntu_2004

docker create \
    --name sftp_ubuntu_2004 \
    -p 9022:22 \
    sftp_ubuntu_2004:v1

docker start \
    sftp_ubuntu_2004
