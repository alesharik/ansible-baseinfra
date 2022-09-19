FROM "{{ nginx.static.git.image }}"-perl
COPY pull.sh /pull.sh
USER root
RUN apk add git bash openssh && adduser --uid {{ userinfo.uid }} {{ nginx.static.git.name }}