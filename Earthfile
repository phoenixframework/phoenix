
all:
    BUILD +all-test
    BUILD +all-integration-test
    BUILD +npm

all-test:
    BUILD --build-arg ELIXIR=1.9.4  --build-arg OTP=20.3.8.26 +test
    BUILD --build-arg ELIXIR=1.10.4 --build-arg OTP=23.1.1 +test
    BUILD --build-arg ELIXIR=1.11.0 --build-arg OTP=21.3.8.18 +test
    BUILD --build-arg ELIXIR=1.11.0 --build-arg OTP=23.1.1 +test
 
test:
    FROM +setup
    COPY --dir assets config installer lib integration_test priv test ./
    RUN mix test

all-integration-test:
    BUILD --build-arg ELIXIR=1.11.1 --build-arg OTP=21.3.8.18 +integration-test
    BUILD --build-arg ELIXIR=1.11.1 --build-arg OTP=23.1.1 +integration-test

integration-test:
    FROM +setup
    COPY --dir assets config installer lib integration_test priv test ./
    WORKDIR /src/installer
    RUN mix deps.get

    WORKDIR /src/integration_test 
    RUN mix deps.get
    WITH DOCKER --compose docker-compose.yml
        RUN mix test --include database
    END 

npm:
    ARG ELIXIR=1.10.4
    ARG OTP=23.0.3
    FROM node:12
    COPY +npm-setup/assets /assets
    WORKDIR assets
    RUN npm install && npm test

npm-setup:
    FROM +setup
    COPY assets assets
    RUN mix deps.get
    SAVE ARTIFACT assets

setup:
   ARG ELIXIR
   ARG OTP
   FROM hexpm/elixir:$ELIXIR-erlang-$OTP-alpine-3.12.0
   WORKDIR /src
   RUN apk add --no-progress --update git
   ENV ELIXIR_ASSERT_TIMEOUT=2000
   COPY mix.exs .
   COPY mix.lock .
   COPY .formatter.exs .
   COPY package.json .
   RUN mix local.rebar --force
   RUN mix local.hex --force
   RUN mix deps.get
