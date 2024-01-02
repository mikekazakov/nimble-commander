#!/bin/sh

docker build --tag nc_sftp_ubuntu_2004 sftp_ubuntu_2004
docker create --name nc_sftp_ubuntu_2004 -p 9022:22 nc_sftp_ubuntu_2004
docker start nc_sftp_ubuntu_2004

docker build --tag nc_webdav_ubuntu_2004 webdav_ubuntu_2004
docker create --name nc_webdav_ubuntu_2004 -p 9080:80 nc_webdav_ubuntu_2004
docker start nc_webdav_ubuntu_2004
