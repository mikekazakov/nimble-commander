#!/bin/sh

docker stop nc_sftp_alpine
docker rm -f nc_sftp_alpine
docker image rm nc_sftp_alpine

docker stop nc_webdav_alpine
docker rm -f nc_webdav_alpine
docker image rm nc_webdav_alpine

docker stop nc_ftp_alpine
docker rm -f nc_ftp_alpine
docker image rm nc_ftp_alpine
