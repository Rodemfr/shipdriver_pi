#!/usr/bin/env bash

#
# Build the flatpak artifacts. Uses docker to run Fedora on
# in fuill-fledged VM; the actual build is done in the Fedora
# container. 
#
# flatpak-builder can be run in a docker image. However, this
# must then be run in privileged mode, which means it we need 
# a full-fledged VM to run it.
#

# bailout on errors and echo commands.
set -xe
sudo systemctl stop apt-daily.service apt-daily.timer
sudo systemctl kill --kill-who=all apt-daily.service

PLUGIN=bsb4

DOCKER_SOCK="unix:///var/run/docker.sock"
TOPDIR=/root/project

echo "DOCKER_OPTS=\"-H tcp://127.0.0.1:2375 -H $DOCKER_SOCK -s devicemapper\"" \
    | sudo tee /etc/default/docker > /dev/null
sudo service docker restart
sleep 5
sudo docker pull fedora:30;
sleep 2
docker run --privileged -d -ti -e "container=docker"  \
    -e "TOPDIR=$TOPDIR" \
    -e "CLOUDSMITH_STABLE_REPO=$CLOUDSMITH_STABLE_REPO" \
    -e "CLOUDSMITH_UNSTABLE_REPO=$CLOUDSMITH_UNSTABLE_REPO" \
    -v /sys/fs/cgroup:/sys/fs/cgroup \
    -v $(pwd):$TOPDIR:rw \
    fedora:30   /bin/bash
DOCKER_CONTAINER_ID=$(docker ps | grep fedora | awk '{print $1}')
docker logs $DOCKER_CONTAINER_ID
docker exec -ti $DOCKER_CONTAINER_ID /bin/bash -xec \
    "bash -xe $TOPDIR/ci/docker-build-flatpak.sh 28;
         echo -ne \"------\nEND OPENCPN-CI BUILD\n\";"
docker ps -a
docker stop $DOCKER_CONTAINER_ID
docker rm -v $DOCKER_CONTAINER_ID

ps -ef | grep apt
sudo systemctl kill --kill-who=all --signal KILL apt-daily.service
sudo rm -f /var/lib/dpkg/lock
sudo apt-get -q update
sudo apt-get install python3-pip python3-setuptools

pip3 install cloudsmith-cli