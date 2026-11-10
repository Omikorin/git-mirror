FROM alpine:3.24.4@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf

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
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
