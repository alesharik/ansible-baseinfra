FROM "{{ nginx.static.git.image }}"-perl
COPY pull.sh /pull.sh
USER root
RUN apk add git bash openssh && echo "{{ nginx.static.git.name }}:x:{{ groupinfo.gid }}:" >> /etc/groups && echo "{{ nginx.static.git.name }}:x:{{ userinfo.uid }}:{{ groupinfo.gid }}:user:/:/bin/false" >> /etc/passwd