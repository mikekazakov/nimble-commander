#!/bin/sh

docker stop sftp_ubuntu_2004

docker rm -f sftp_ubuntu_2004

docker image rm sftp_ubuntu_2004:v1
