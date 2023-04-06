FROM alpine:3.17.3

ENV RUNNER="runner"

COPY apk.txt /
RUN tr '\n' '\0' < apk.txt | xargs -0 apk add --no-cache  \
&& ( getent passwd "${RUNNER}" || adduser -D "${RUNNER}" )

COPY alpine_package_finder.bash /bin/
ENTRYPOINT ["/bin/alpine_package_finder.bash"]
HEALTHCHECK NONE
USER "${RUNNER}"
