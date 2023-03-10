You are running heroicons v2.0.16. To upgrade in place, you can run the following command,
where your `HERO_VSN` export is your desired version:

    export HERO_VSN="2.0.16" ; \
      curl -L -o optimized.tar.gz "https://github.com/tailwindlabs/heroicons/archive/refs/tags/v${HERO_VSN}.tar.gz" ; \
      tar --strip-components=1 -xvf optimized.tar.gz heroicons-${HERO_VSN}/optimized ; \
      rm optimized.tar.gz
