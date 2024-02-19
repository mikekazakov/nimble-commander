#!/bin/sh

docker build --tag nc_sftp_ubuntu_2004 sftp_ubuntu_2004
docker create --name nc_sftp_ubuntu_2004 -p 127.0.0.1:9022:22 nc_sftp_ubuntu_2004
docker start nc_sftp_ubuntu_2004

docker build --tag nc_webdav_ubuntu_2004 webdav_ubuntu_2004
docker create --name nc_webdav_ubuntu_2004 -p 127.0.0.1:9080:80 nc_webdav_ubuntu_2004
docker start nc_webdav_ubuntu_2004

docker build --tag nc_ftp_ubuntu_2004 ftp_ubuntu_2004
docker create --name nc_ftp_ubuntu_2004 -p 127.0.0.1:9020:20 -p 127.0.0.1:9021:21 -p 127.0.0.1:47400-47470:47400-47470 nc_ftp_ubuntu_2004
docker start nc_ftp_ubuntu_2004
