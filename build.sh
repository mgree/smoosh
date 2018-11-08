#!/bin/sh

docker build -t smoosh .
docker build -t smoosh-test -f Dockerfile.test .
docker run smoosh-test
