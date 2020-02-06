#!/bin/sh

# camlp4 won't work in 4.08 right now 2019-06-18
opam init
opam switch 4.07.0

eval `opam config env`

echo ". /home/vagrant/.opam/opam-init/init.sh > /dev/null 2> /dev/null || true" >>~/.profile
cat >~/.ocamlinit <<EOF
let () =
  try Topdirs.dir_directory (Sys.getenv "OCAML_TOPLEVEL_PATH")
  with Not_found -> ()
;;
EOF

# make sure we have ocamlfind and ocamlbuild
opam install ocamlfind ocamlbuild

# set up FFI for libdash; num library for lem; extunix for shell syscalls
opam pin -n add ctypes 0.11.5
opam install ctypes ctypes-foreign num extunix

# build Oil... (disabled due to buggy libc test)
# cd oil; ./configure; build/dev.sh minimal
# sed -i 's#REPO_ROOT=.*#REPO_ROOT=/home/opam/oil#' /home/opam/oil/bin/osh
# sudo ln -sf /home/opam/oil/bin/osh /usr/local/bin/osh

cp -R smoosh.orig smoosh

cd smoosh

# set up lem
(cd lem; make clean) # clear things out in case local repo has been built
(cd lem/ocaml-lib; make install_dependencies)
(cd lem; make; make install)
PATH="/home/vagrant/smoosh/lem/bin:${PATH}"
LEMLIB="/home/vagrant/smoosh/lem/library"
export LEMLIB

cat >>~/.profile <<EOF

unset LS_COLORS # breakage w/Modernish
unset GCC_COLORS

PATH="/home/vagrant/smoosh/lem/bin:${PATH}"
LEMLIB="/home/vagrant/smoosh/lem/library"
export LEMLIB
EOF

# build libdash, expose shared object
(cd libdash; ./autogen.sh && ./configure --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu)
(cd libdash; make clean && make && sudo make install)
# build ocaml bindings
(cd libdash/ocaml; make && make install)

# build smoosh
(cd src; make clean && make all)

# install smoosh
sudo cp src/smoosh /bin/smoosh

