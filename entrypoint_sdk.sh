#!/bin/sh

# find the environment setup file
environment_setup_file="$(find /sdk -type f -name 'environment-setup-*')"

# source the environment setup file
. "${environment_setup_file}"

# execute command args
"$@"
