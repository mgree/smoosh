#!/bin/sh

echo "************************************************************************"
echo "* INSTALLING DEPENDENCIES **********************************************"
echo "************************************************************************"

set -o errexit

# silence apt-get
DEBIAN_FRONTEND=noninteractive
export DEBIAN_FRONTEND

# we frontload installation so that things that inherit from us don't need network access
# we also (inadvisedly) do an update, but we'll ask for particular shell versions
apt-get update

# convenience
apt-get install emacs24-nox

# POSIX test suite commands
apt-get install -y --no-install-recommends expect
apt-get install -y gawk

# other shells we'll want
apt-get install -y dash=0.5.8-2.4
apt-get install -y --no-install-recommends bash=4.4-5
apt-get install -y yash=2.43-1
apt-get install -y zsh=5.3.1-4+b3 && echo 'emulate sh' >~/.zshrc
apt-get install -y ksh=93u+20120801-3.1
apt-get install -y mksh=54-2+b4

# keep a copy
cp /bin/sh /bin/sh.bak

# for OSH
#apt-get install -y python2.7 python python-dev time libreadline-dev

# system support for libdash; libgmp for zarith for lem
apt-get install -y autoconf autotools-dev libtool pkg-config libffi-dev libgmp-dev
apt-get install -y bc opam

echo "************************************************************************"
echo "* BUILDING SMOOSH ******************************************************"
echo "************************************************************************"

su -c ". /home/vagrant/smoosh.orig/vagrant/build.sh" vagrant
