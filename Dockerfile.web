FROM smoosh

# :( things go out of date with Debian so quickly
RUN sudo apt-get update
RUN sudo apt-get install -y ruby-full ruby-bundler
RUN sudo gem install -v 0.9.0 childprocess 
RUN sudo gem install -v 2.0.4 sinatra
RUN sudo gem install -v 2.0.4 sinatra-contrib
RUN sudo gem install -v 1.7.2 thin

ADD --chown=opam:opam web web
RUN cd web; bundle install
RUN mv web/src/config.yml.docker web/src/config.yml
RUN mkdir web/submissions
VOLUME web/submissions

EXPOSE 2080/tcp
#EXPOSE 2443/tcp

HEALTHCHECK CMD curl --fail --data-ascii @web/test.post http://localhost:2080/stepper

#ENTRYPOINT [ "opam", "config", "exec", "--" ]
CMD /home/opam/web/run.sh
