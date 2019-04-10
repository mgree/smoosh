#!/bin/sh

set -e

build=$(date "+%Y-%m-%d_%H:%M")

cat <<EOF
open import Pervasives_extra

val smoosh_version : string
let smoosh_version = "0.1"

val smoosh_build : string
let smoosh_build = "$build"

val smoosh_info : string
let smoosh_info = "smoosh v" ^ smoosh_version ^ " (build " ^ smoosh_build ^ ")\n"
EOF
