#!/bin/bash

if [ -z "$ZEPHYR_SOURCE" ]; then
	export ZEPHYR_SOURCE=https://gerrit.zephyrproject.org/r/zephyr
fi

if [ -z "$ZEPHYR_PLATFORM" ]; then
	export ZEPHYR_PLATFORM=qemu_cortex_m3
fi

if [ -z "$BUILD_ID" ]; then
	export BUILD_ID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
fi

if [ -z "$ZEPHYR_OUTDIR" ]; then
	mkdir -p /mnt/artifacts/$BUILD_ID
	export ZEPHYR_OUTDIR=/mnt/artifacts/$BUILD_ID
else
	mkdir -p $ZEPHYR_OUTDIR
fi

# Update Mirror
cd /srv/mirrors/zephyr-mirror
echo "Source Mirror Update Started $(date +"%T")" > /mnt/artifacts/$BUILD_ID/results.txt
git remote update
echo "Source Mirror Update Finished $(date +"%T")" >> /mnt/artifacts/$BUILD_ID/results.txt

# Clone and Build
cd /root
echo "Clone Source Started $(date +"%T")" >> /mnt/artifacts/$BUILD_ID/results.txt
git clone --reference /srv/mirrors/zephyr-mirror $ZEPHYR_SOURCE zephyr-project
echo "Clone Source Finished $(date +"%T")" >> /mnt/artifacts/$BUILD_ID/results.txt
cd zephyr-project
# Hack to build for now
git config --global user.email "tyler.baker@linaro.org"
git config --global user.name "Tyler Baker"
git fetch https://gerrit.zephyrproject.org/r/zephyr refs/changes/65/4565/3 && git cherry-pick FETCH_HEAD
source zephyr-env.sh
echo "Build Started $(date +"%T")" >> /mnt/artifacts/$BUILD_ID/results.txt
sanitycheck --platform $ZEPHYR_PLATFORM --build-only --outdir $ZEPHYR_OUTDIR --enable-slow --no-clean
echo "Build Finished $(date +"%T")" >> /mnt/artifacts/$BUILD_ID/results.txt

# Test
echo "Fetching LAVA API Key Started $(date +"%T")" >> /mnt/artifacts/$BUILD_ID/results.txt
wget http://lava-titan/tmp/apikey.txt
echo "Fetching LAVA API Key Finished $(date +"%T")" >> /mnt/artifacts/$BUILD_ID/results.txt
echo "Running Tests Started $(date +"%T")" >> /mnt/artifacts/$BUILD_ID/results.txt
sed -i -e "s/{PLATFORM}/$ZEPHYR_PLATFORM/g" *.yaml
sed -i -e "s/{BUILD}/$BUILD_ID/g" *.yaml
./submityaml.py -k apikey.txt -p aes128-test.yaml aes128-cbc-test.yaml ccm-mode-test.yaml cmac-mode-test.yaml aes128-ctr-mode-test.yaml hmac-rfc4231-vectors-test.yaml mbedtls-test.yaml hmac-prng-test.yaml nano-lifo-test.yaml nano-work-test.yaml microkernel-memory-map-test.yaml microkernel-memory-pool-test.yaml microkernel-mutex-api-test.yaml early-sleep-test.yaml atomic-operation-primitives.yaml sleep-tests.yaml mem-safe.yaml events-test.yaml rand32-test.yaml mailbox-test.yaml irq-offload-test.yaml ring-buffer-test.yaml task-api-test.yaml pipe-tests.yaml arm-m3-irq-vector-table.yaml context-test.yaml errno-test.yaml ipm-test.yaml critical-section-api-test.yaml pending-tasks-test.yaml sprintf-api-test.yaml micro-xip-test.yaml nano-xip-test.yaml micro-timers-test.yaml nano-xip-test.yaml 
echo "Running Tests Finished $(date +"%T")" >> /mnt/artifacts/$BUILD_ID/results.txt
cd /cat results.txt >> /mnt/artifacts/$BUILD_ID/results.txt
