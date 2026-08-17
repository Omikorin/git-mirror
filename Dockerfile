FROM alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b

LABEL com.github.actions.name="Git Mirror" \
      com.github.actions.description="Mirror a public or private repository. Compatible with LFS." \
      com.github.actions.icon="git-branch" \
      com.github.actions.color="purple" \
      maintainer="@Omikorin" \
      org.opencontainers.image.title="Git Mirror" \
      org.opencontainers.image.description="Mirror a public or private repository. Compatible with LFS." \
      org.opencontainers.image.url="https://github.com/Omikorin/git-mirror" \
      org.opencontainers.image.source="https://github.com/Omikorin/git-mirror" \
      org.opencontainers.image.licenses="ISC"

RUN apk update && apk upgrade && \
    apk add --no-cache git git-lfs openssh && \
    git lfs install

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
