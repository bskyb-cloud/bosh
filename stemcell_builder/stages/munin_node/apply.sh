#!/usr/bin/env bash

#

# Copyright (c) 2009-2012 VMware, Inc.



set -e



base_dir=$(readlink -nf $(dirname $0)/../..)

source $base_dir/lib/prelude_apply.bash



# Disable interactive dpkg

debconf="debconf debconf/frontend select noninteractive"

run_in_chroot $chroot "echo ${debconf} | debconf-set-selections"



# Install base debs needed by both the warden and bosh

debs="munin-node"



pkg_mgr install $debs
