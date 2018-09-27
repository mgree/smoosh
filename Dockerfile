# start with a reasonable image. Debian 9 stretch is what's on the POSIX testing VM
FROM ocaml/opam:debian-9_ocaml-4.05.0

# silence apt
ARG DEBIAN_FRONTEND=noninteractive

# make sure we have ocamlfind
RUN opam install ocamlfind

# set up zarith
RUN sudo apt-get install -y libgmp-dev
#RUN opam pin add zarith 1.2

# set up lem
RUN git clone https://github.com/rems-project/lem.git
RUN cd ~/lem/ocaml-lib; sudo make install_dependencies
RUN cd lem; make
RUN cd lem; sudo make install
ENV PATH="/home/opam/lem/bin:${PATH}"

# set up OPAM for libdash
RUN sudo apt-get install -y libffi-dev && \
    opam pin add ctypes 0.11.5 && \
    opam install ctypes-foreign

ENTRYPOINT [ "opam", "config", "exec", "--" ]
CMD [ "bash" ]
