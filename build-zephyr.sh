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
fi

git clone $ZEPHYR_SOURCE zephyr-project
cd zephyr-project
source zephyr-env.sh
sanitycheck --platform $ZEPHYR_PLATFORM --build-only --outdir $ZEPHYR_OUTDIR --enable-slow
