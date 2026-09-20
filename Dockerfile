FROM nixos/nix:2.30.3@sha256:d378876de1dca0534fc9fd3c03b1c6adf28447b87b65cb352060871570ace15b

ARG LEARNER_UID=1000
ARG LEARNER_GID=1000

RUN cp -L /etc/passwd /tmp/passwd \
    && cp -L /etc/group /tmp/group \
    && rm /etc/passwd /etc/group \
    && mv /tmp/passwd /etc/passwd \
    && mv /tmp/group /etc/group \
    && printf 'learner:x:%s:%s:Nix learner:/home/learner:/bin/sh\n' \
        "${LEARNER_UID}" "${LEARNER_GID}" >> /etc/passwd \
    && printf 'learner:x:%s:\n' "${LEARNER_GID}" >> /etc/group \
    && mkdir -p /workspace /home/learner/.cache/nix \
    && chown -R learner:learner /nix /workspace /home/learner

COPY --chown=learner:learner scripts /opt/nix-lab/scripts
RUN chmod +x /opt/nix-lab/scripts/lab /opt/nix-lab/scripts/check

ENV HOME=/home/learner
ENV USER=learner
ENV NIX_CONFIG="experimental-features = nix-command flakes"
ENV PATH="/home/learner/.nix-profile/bin:${PATH}"
WORKDIR /workspace
USER learner

ENTRYPOINT ["/opt/nix-lab/scripts/lab"]
CMD ["shell"]
