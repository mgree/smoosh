# start with a reasonable image. Debian 9 stretch is what's on the POSIX testing VM
FROM ocaml/opam:debian-9_ocaml-4.05.0

# silence apt
# TODO this still isn't silencing it :(
ENV DEBIAN_FRONTEND=noninteractive

# make sure we have ocamlfind
RUN opam install ocamlfind

# set up zarith
RUN sudo apt-get install -y libgmp-dev
#RUN opam install zarith

# set up OPAM for libdash
RUN sudo apt-get install -y libffi-dev && \
    opam pin add ctypes 0.11.5 && \
    opam install ctypes-foreign

# system support for libdash
RUN sudo apt-get install -y autoconf libtool

# set up lem
# TODO fix a Lem version to use
RUN git clone https://github.com/rems-project/lem.git
RUN cd ~/lem/ocaml-lib; opam config exec -- make install_dependencies
RUN cd lem; opam config exec -- make
ENV PATH="/home/opam/lem/bin:${PATH}"
ENV LEMLIB="/home/opam/lem/library"

# copy in repo files for libdash to the WORKDIR (should be /home/opam)
# we do this as late as possible so we don't have to redo the slow stuff above
ADD --chown=opam:opam libdash libdash

# build libdash, expose shared object
RUN cd libdash; ./autogen.sh && ./configure --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu
RUN cd libdash; make
RUN cd libdash; sudo make install
# build ocaml bindings
RUN cd libdash/ocaml; opam config exec -- make && opam config exec -- make install

# copy in repo files for smoosh to the WORKDIR
ADD --chown=opam:opam src src
ADD --chown=opam:opam README.md .

# build smoosh
#RUN cd src; opam config exec -- make

ENTRYPOINT [ "opam", "config", "exec", "--" ]
CMD [ "bash" ]
