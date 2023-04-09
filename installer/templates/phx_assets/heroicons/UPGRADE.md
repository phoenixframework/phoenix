You are running heroicons v2.0.17. To upgrade in place, you can run the following command,
where your `HERO_VSN` export is your desired version:

    export HERO_VSN="2.0.17" ; \
      curl -L "https://github.com/tailwindlabs/heroicons/archive/refs/tags/v${HERO_VSN}.tar.gz" | \
      tar -xzv --strip-components=1 heroicons-${HERO_VSN}/optimized
