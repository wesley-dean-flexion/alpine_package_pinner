FROM alpine:3.17.3

ENV RUNNER="runner"

COPY apk-lock.txt /
RUN xargs < /apk-lock.txt apk add --no-cache \
&& ( getent passwd "${RUNNER}" || adduser -D "${RUNNER}" )

COPY alpine_package_finder.bash /bin/
ENTRYPOINT ["/bin/alpine_package_finder.bash"]
HEALTHCHECK NONE
USER "${RUNNER}"
