#!/bin/sh

docker stop nc_sftp_ubuntu_2004
docker rm -f nc_sftp_ubuntu_2004
docker image rm nc_sftp_ubuntu_2004

docker stop nc_webdav_ubuntu_2004
docker rm -f nc_webdav_ubuntu_2004
docker image rm nc_webdav_ubuntu_2004

docker stop nc_ftp_ubuntu_2004
docker rm -f nc_ftp_ubuntu_2004
docker image rm nc_ftp_ubuntu_2004
