#!/bin/bash

if [ -z "$ZEPHYR_PLATFORM" ]; then
	export ZEPHYR_PLATFORM=qemu_cortex_m3
fi

echo "Fetching LAVA API Key Started $(date +"%T")" >> /var/www/html/seq.txt
wget http://lava/tmp/apikey.txt
echo "Fetching LAVA API Key Finished $(date +"%T")" >> /var/www/html/seq.txt
echo "Running Tests Started $(date +"%T")" >> /var/www/html/seq.txt
sed -i -e "s/localhost/$(hostname -I | tr -d '[[:space:]]')/g" *.yaml
sed -i -e "s/{PLATFORM}/$ZEPHYR_PLATFORM/g" *.yaml
./submityaml.py -k apikey.txt -p aes128-test.yaml aes128-cbc-test.yaml ccm-mode-test.yaml cmac-mode-test.yaml aes128-ctr-mode-test.yaml hmac-rfc4231-vectors-test.yaml mbedtls-test.yaml hmac-prng-test.yaml nano-lifo-test.yaml nano-work-test.yaml microkernel-memory-map-test.yaml microkernel-memory-pool-test.yaml microkernel-mutex-api-test.yaml early-sleep-test.yaml atomic-operation-primitives.yaml sleep-tests.yaml mem-safe.yaml events-test.yaml rand32-test.yaml mailbox-test.yaml irq-offload-test.yaml ring-buffer-test.yaml task-api-test.yaml pipe-tests.yaml arm-m3-irq-vector-table.yaml context-test.yaml errno-test.yaml ipm-test.yaml critical-section-api-test.yaml pending-tasks-test.yaml sprintf-api-test.yaml micro-xip-test.yaml nano-xip-test.yaml micro-timers-test.yaml nano-xip-test.yaml 
echo "Running Tests Finished $(date +"%T")" >> /var/www/html/seq.txt
cat results.txt >> /var/www/html/seq.txt
