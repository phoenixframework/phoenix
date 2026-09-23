ARG ELIXIR_IMAGE_TAG

FROM hexpm/elixir:${ELIXIR_IMAGE_TAG}

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git socat \
    && rm -rf /var/lib/apt/lists/* \
    && if id -u ubuntu >/dev/null 2>&1; then \
        usermod -l runner -d /home/runner -m ubuntu && groupmod -n runner ubuntu; \
    else \
        useradd -m -u 1000 -s /bin/bash runner; \
    fi \
    && mkdir -p /home/runner/.mix /home/runner/.hex /phoenix/integration_test/_build /phoenix/integration_test/deps /phoenix/installer/tmp \
    && chown -R runner:runner /home/runner /phoenix

USER runner
WORKDIR /phoenix/integration_test

RUN mix local.hex --force \
    && mix local.rebar --force

COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--include", "database"]
