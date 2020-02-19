#!/bin/sh

set -e

time=$(date "+%Y-%m-%d %H:%M")
build=$(git describe --always)

cat <<EOF
open import Pervasives_extra

val smoosh_version : string
let smoosh_version = "0.1"

val smoosh_build : string
let smoosh_build = "$build"

val smoosh_time : string
let smoosh_time = "$time"

val smoosh_info : string
let smoosh_info = "smoosh v" ^ smoosh_version ^ " (build " ^ smoosh_build ^ " on " ^ smoosh_time ^ ")\n"
EOF
