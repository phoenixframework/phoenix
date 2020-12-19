all:
    BUILD +all-test
    BUILD +all-integration-test
    BUILD +npm

all-test:
    BUILD --build-arg ELIXIR=1.11.0 --build-arg OTP=21.3.8.18 +test
    BUILD --build-arg ELIXIR=1.11.0 --build-arg OTP=23.1.1 +test

test:
    FROM +test-setup
    COPY --dir assets config installer lib integration_test priv test ./
    RUN mix test

all-integration-test:
    BUILD --build-arg ELIXIR=1.11.1 --build-arg OTP=21.3.8.18 +integration-test
    BUILD --build-arg ELIXIR=1.11.1 --build-arg OTP=23.1.1 +integration-test

integration-test:
    FROM +setup-base

    RUN apk add --no-progress --update docker docker-compose

    # Install tooling needed to check if the DBs are actually up when performing integration tests
    RUN apk add postgresql-client mysql-client
    RUN apk add --no-cache curl gnupg --virtual .build-dependencies -- && \
        curl -O https://download.microsoft.com/download/e/4/e/e4e67866-dffd-428c-aac7-8d28ddafb39b/msodbcsql17_17.5.2.1-1_amd64.apk && \
        curl -O https://download.microsoft.com/download/e/4/e/e4e67866-dffd-428c-aac7-8d28ddafb39b/mssql-tools_17.5.2.1-1_amd64.apk && \
        echo y | apk add --allow-untrusted msodbcsql17_17.5.2.1-1_amd64.apk mssql-tools_17.5.2.1-1_amd64.apk && \
        apk del .build-dependencies && rm -f msodbcsql*.sig mssql-tools*.apk
    ENV PATH="/opt/mssql-tools/bin:${PATH}"

    # Integration test deps
    COPY /integration_test/docker-compose.yml ./integration_test/docker-compose.yml
    COPY mix.exs ./
    COPY /.formatter.exs ./
    COPY /installer/mix.exs ./installer/mix.exs
    COPY /integration_test/mix.exs ./integration_test/mix.exs
    COPY /integration_test/mix.lock ./integration_test/mix.lock
    COPY /integration_test/config/config.exs ./integration_test/config/config.exs
    WORKDIR /src/integration_test
    RUN mix local.hex --force

    # Ensure integration_test/mix.lock contains all of the dependencies we need and none we don't
    RUN cp mix.lock mix.lock.orig && \
        mix deps.get && \
        mix deps.unlock --check-unused && \
        diff -u mix.lock.orig mix.lock && \
        rm mix.lock.orig


    # Compile phoenix
    COPY --dir assets config installer lib test priv /src
    RUN mix local.rebar --force
    # Compiling here improves caching, but slows down GHA speed
    # Removing until this feature exists https://github.com/earthly/earthly/issues/574
    # RUN MIX_ENV=test mix deps.compile

    # Run integration tests
    COPY integration_test/test  ./test
    COPY integration_test/config/config.exs  ./config/config.exs

    WITH DOCKER
        # Start docker compose
        # In parallel start compiling tests
        # Check for DB to be up x 3
        # Run the database tests
        RUN docker-compose up -d & \
            MIX_ENV=test mix deps.compile && \
            while ! sqlcmd -S tcp:localhost,1433 -U sa -P 'some!Password' -Q "SELECT 1" > /dev/null 2>&1; do sleep 1; done; \
            while ! mysqladmin ping --host=localhost --port=3306 --protocol=TCP --silent; do sleep 1; done; \
            while ! pg_isready --host=localhost --port=5432 --quiet; do sleep 1; done; \
            mix test --include database
    END

npm:
    ARG ELIXIR=1.10.4
    ARG OTP=23.0.3
    FROM node:12
    COPY +npm-setup/assets /assets
    WORKDIR assets
    RUN npm install && npm test

npm-setup:
    FROM +test-setup
    COPY assets assets
    RUN mix deps.get
    SAVE ARTIFACT assets

setup-base:
   ARG ELIXIR=1.11.2
   ARG OTP=23.1.1
   FROM hexpm/elixir:$ELIXIR-erlang-$OTP-alpine-3.12.0
   RUN apk add --no-progress --update git build-base
   ENV ELIXIR_ASSERT_TIMEOUT=10000
   WORKDIR /src

test-setup:
   FROM +setup-base
   COPY mix.exs .
   COPY mix.lock .
   COPY .formatter.exs .
   COPY package.json .
   RUN mix local.rebar --force
   RUN mix local.hex --force
   RUN mix deps.get
