#!/bin/bash

if [ -z "$ZEPHYR_SOURCE" ]; then
	export ZEPHYR_SOURCE=https://gerrit.zephyrproject.org/r/zephyr
fi

if [ -z "$ZEPHYR_PLATFORM" ]; then
	export ZEPHYR_PLATFORM=qemu_cortex_m3
fi

if [ -z "$ZEPHYR_OUTDIR" ]; then
	mkdir -p /root/zephyr-outdir
	export ZEPHYR_OUTDIR=/root/zephyr-outdir
else
	mkdir -p $ZEPHYR_OUTDIR
fi

echo "Clone Source Started $(date +"%T")" >> /var/www/html/seq.txt
git clone --reference /srv/mirrors/zephyr-mirror $ZEPHYR_SOURCE zephyr-project
echo "Clone Source Finished $(date +"%T")" >> /var/www/html/seq.txt
cd zephyr-project
source zephyr-env.sh
echo "Build Started $(date +"%T")" >> /var/www/html/seq.txt
sanitycheck --platform $ZEPHYR_PLATFORM --build-only --outdir $ZEPHYR_OUTDIR --enable-slow
echo "Build Finished $(date +"%T")" >> /var/www/html/seq.txt
