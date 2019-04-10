#!/bin/sh

docker build -t smoosh . && \
sleep 1 && \
docker build -t smoosh-test -f Dockerfile.test . && \
sleep 1 && \    
docker run smoosh-test
