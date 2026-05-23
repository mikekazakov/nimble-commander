#!/bin/sh

docker build --tag nc_sftp_alpine sftp_alpine
docker create --name nc_sftp_alpine -p 127.0.0.1:9022:22 nc_sftp_alpine
docker start nc_sftp_alpine

docker build --tag nc_webdav_alpine webdav_alpine
docker create --name nc_webdav_alpine -p 127.0.0.1:9080:80 nc_webdav_alpine
docker start nc_webdav_alpine

docker build --tag nc_ftp_alpine ftp_alpine
docker create --name nc_ftp_alpine -p 127.0.0.1:9020:20 -p 127.0.0.1:9021:21 -p 127.0.0.1:47400-47470:47400-47470 nc_ftp_alpine
docker start nc_ftp_alpine
