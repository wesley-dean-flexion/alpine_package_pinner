FROM alpine:3.18.0

ENV RUNNER="runner"
SHELL ["/bin/ash", "-o", "pipefail", "-c"]

COPY apk.txt /
RUN tr '\n' '\0' < apk.txt | xargs -0 apk add --no-cache  \
&& ( getent passwd "${RUNNER}" || adduser -D "${RUNNER}" )

COPY alpine_package_finder.bash /bin/
ENTRYPOINT ["/bin/alpine_package_finder.bash"]
HEALTHCHECK NONE
USER "${RUNNER}"
