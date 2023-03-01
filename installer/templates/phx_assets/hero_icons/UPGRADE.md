You are running heroicons v2.0.16. To upgrade in place, you can run the following command,
where your `HERO_VSN` export is your desired version:

    export HERO_VSN="2.0.16" ; \
      curl -L -o optimized.zip "https://github.com/tailwindlabs/heroicons/archive/refs/tags/v${HERO_VSN}.zip" ; \
      tar --strip-components=1 -xvf optimized.zip heroicons-${HERO_VSN}/optimized ; \
      rm optimized.zip
