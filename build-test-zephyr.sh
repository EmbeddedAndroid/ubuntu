#!/bin/bash

if [ -z "$ZEPHYR_SOURCE" ]; then
	export ZEPHYR_SOURCE=https://gerrit.zephyrproject.org/r/zephyr
fi

if [ -z "$ZEPHYR_PLATFORM" ]; then
	export ZEPHYR_PLATFORM=qemu_cortex_m3
fi

if [ -z "$ZEPHYR_BUILD_ID" ]; then
	export ZEPHYR_BUILD_ID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
fi

if [ -z "$ZEPHYR_OUTDIR" ]; then
	mkdir -p /mnt/artifacts/$ZEPHYR_BUILD_ID
	export ZEPHYR_OUTDIR=/mnt/artifacts/$ZEPHYR_BUILD_ID
else
	mkdir -p $ZEPHYR_OUTDIR
fi

# Update Mirror
cd /srv/mirrors/zephyr-mirror
git remote update
if [ $? -ne 0 ]; then
	python /root/logger.py -t KILL -s FAIL -m "Source Mirror Updated" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	exit 1
else
	python /root/logger.py -t INFO -s OK -m "Source Mirror Updated" -i $ZEPHYR_BUILD_ID -b broker -p 5555
fi

# Build Developer Images
cd /root
mkdir -p /root/dev
git clone --reference /srv/mirrors/zephyr-mirror $ZEPHYR_SOURCE zephyr-project
if [ $? -ne 0 ]; then
	python /root/logger.py -t KILL -s FAIL -m "Checkout User Source Code" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	exit 1
else
	python /root/logger.py -t INFO -s OK -m "Checkout User Source Code" -i $ZEPHYR_BUILD_ID -b broker -p 5555
fi
cd zephyr-project
source zephyr-env.sh
python /root/logger.py -t INFO -s OK -m "Developer Image Builds Started" -i $ZEPHYR_BUILD_ID -b broker -p 5555
sanitycheck --platform $ZEPHYR_PLATFORM --build-only --outdir /root/dev --no-clean --testcase-root=tests/kernel --testcase-root=tests/crypto -j 100
if [ $? -ne 0 ]; then
	python /root/logger.py -t KILL -s FAIL -m "Developer Images Built" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	exit 1
else
	python /root/logger.py -t INFO -s OK -m "Developer Images Built" -i $ZEPHYR_BUILD_ID -b broker -p 5555
fi

# Publish Developer Images
python /root/logger.py -t INFO -s OK -m "Developer Image Publishing Started" -i $ZEPHYR_BUILD_ID -b broker -p 5555
cd /root/dev
rsync -avm --include='*.bin' --include='*.log' --include='*.hex' -f 'hide,! */' . $ZEPHYR_OUTDIR
if [ $? -ne 0 ]; then
	python /root/logger.py -t KILL -s FAIL -m "Developer Images Published" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	exit 1
else
	python /root/logger.py -t INFO -s OK -m "Developer Images Published" -i $ZEPHYR_BUILD_ID -b broker -p 5555
fi

# Test Developer Images
cd /root
wget http://lava-titan:9003/tmp/apikey.txt
if [ $? -ne 0 ]; then
	python /root/logger.py -t KILL -s FAIL -m "Obtained LAVA API Key" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	exit 1
else
	python /root/logger.py -t INFO -s OK -m "Obtained LAVA API Key" -i $ZEPHYR_BUILD_ID -b broker -p 5555
fi

python /root/logger.py -t INFO -s OK -m "Developer Image Testing Started" -i $ZEPHYR_BUILD_ID -b broker -p 5555
sed -i -e "s/{PLATFORM}/$ZEPHYR_PLATFORM/g" *.yaml
sed -i -e "s/{BUILD}/$ZEPHYR_BUILD_ID/g" *.yaml
./submityaml.py -k apikey.txt -p --port 9003 aes128-test.yaml aes128-cbc-test.yaml ccm-mode-test.yaml cmac-mode-test.yaml aes128-ctr-mode-test.yaml hmac-rfc4231-vectors-test.yaml mbedtls-test.yaml hmac-prng-test.yaml nano-lifo-test.yaml nano-work-test.yaml microkernel-memory-map-test.yaml microkernel-memory-pool-test.yaml microkernel-mutex-api-test.yaml early-sleep-test.yaml atomic-operation-primitives.yaml sleep-tests.yaml mem-safe.yaml events-test.yaml rand32-test.yaml mailbox-test.yaml irq-offload-test.yaml ring-buffer-test.yaml task-api-test.yaml pipe-tests.yaml arm-m3-irq-vector-table.yaml errno-test.yaml ipm-test.yaml critical-section-api-test.yaml pending-tasks-test.yaml sprintf-api-test.yaml micro-xip-test.yaml nano-xip-test.yaml micro-timers-test.yaml nano-xip-test.yaml
if [ $? -ne 0 ]; then
	python /root/logger.py -t KILL -s FAIL -m "Developer Image Tests" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	exit 1
else
	python /root/logger.py -t INFO -s OK -m "Developer Image Tests" -i $ZEPHYR_BUILD_ID -b broker -p 5555
fi 
cat results.txt >> /mnt/artifacts/$ZEPHYR_BUILD_ID/$ZEPHYR_PLATFORM/results.txt

# Build Production Images

if [ -d "/root/zephyr-project/samples/linaro_fota" ]; then
	mkdir -p /root/prod/nrf52_nitrogen/samples/linaro_fota
	cd /root/zephyr-project
	source zephyr-env.sh
        cd samples/linaro_fota
	python /root/logger.py -t INFO -s OK -m "Production Image Builds Started" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	make CONF_FILE=prj_nrf52.conf BOARD=nrf52_nitrogen O=/root/prod/nrf52_nitrogen/samples/linaro_fota -j 100
	if [ $? -ne 0 ]; then
		python /root/logger.py -t KILL -s FAIL -m "Production Images Built" -i $ZEPHYR_BUILD_ID -b broker -p 5555
		exit 1
	else
		python /root/logger.py -t INFO -s OK -m "Production Images Build" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	fi 

	# Sign Production Images
	python /root/logger.py -t INFO -s OK -m "Signing Production Images Started" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	python /root/zep2newt.py --bin /root/prod/nrf52_nitrogen/samples/linaro_fota/zephyr.bin --out /root/prod/nrf52_nitrogen/samples/linaro_fota/zephyr-unsigned-dfu.bin
	if [ $? -ne 0 ]; then
		python /root/logger.py -t KILL -s FAIL -m "Unsigned Production Images Built" -i $ZEPHYR_BUILD_ID -b broker -p 5555
		exit 1
	else
		python /root/logger.py -t INFO -s OK -m "Unsigned Production Images Built" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	fi

	python /root/zep2newt.py --bin /root/prod/nrf52_nitrogen/samples/linaro_fota/zephyr.bin --key /root/image_sign.pem --sig RSA --out /root/prod/nrf52_nitrogen/samples/linaro_fota/zephyr-signed-dfu.bin
	if [ $? -ne 0 ]; then
		python /root/logger.py -t KILL -s FAIL -m "Signed Production Images Built" -i $ZEPHYR_BUILD_ID -b broker -p 5555
		exit 1
	else
		python /root/logger.py -t INFO -s OK -m "Signed Production Images Built" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	fi  

	# Publish Production Images
	python /root/logger.py -t INFO -s OK -m "Production Image Publishing Started" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	cd /root/prod
	rsync -avm --include='*.bin' --include='*.log' --include='*.hex' -f 'hide,! */' . $ZEPHYR_OUTDIR
	if [ $? -ne 0 ]; then
		python /root/logger.py -t KILL -s FAIL -m "Production Images Published" -i $ZEPHYR_BUILD_ID -b broker -p 5555
		exit 1
	else
		python /root/logger.py -t INFO -s OK -m "Production Images Published" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	fi

	# Test Production Images
	python /root/logger.py -t INFO -s OK -m "Production Image Testing Started" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	sleep 5
	python /root/logger.py -t TEST -s PASS -m "test-shell : main" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	echo "test-linaro_fota : main : pass" >> /mnt/artifacts/$ZEPHYR_BUILD_ID/nrf52_nitrogen/results.txt
	if [ $? -ne 0 ]; then
		python /root/logger.py -t KILL -s FAIL -m "Production Image Tests" -i $ZEPHYR_BUILD_ID -b broker -p 5555
		exit 1
	else
		python /root/logger.py -t INFO -s OK -m "Production Image Tests" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	fi

	python /root/logger.py -t INFO -s OK -m "Automated Building and Testing Finished" -i $ZEPHYR_BUILD_ID -b broker -p 5555

	# Deploy to Hawkbit
	python /root/logger.py -t INFO -s OK -m "Deploying Production Images to Device Management System" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	python /root/hawkbit.py -p "Linaro" -n "Unsigned Linaro IoT RPB - Nitrogen - FOTA" -d "Signed Linaro IoT Reference Plaform - Nitrogen - FOTA" -sv "v1.0-beta-${ZEPHYR_BUILD_ID::12}" -t os -f /root/prod/nrf52_nitrogen/samples/linaro_fota/zephyr-unsigned-dfu.bin
	python /root/hawkbit.py -p "Linaro" -n "Signed Linaro IoT RPB - Nitrogen - FOTA" -d "Signed Linaro IoT Reference Plaform - Nitrogen - FOTA" -sv "v1.0-beta-${ZEPHYR_BUILD_ID::12}" -t os -f /root/prod/nrf52_nitrogen/samples/linaro_fota/zephyr-signed-dfu.bin
	if [ $? -ne 0 ]; then
		python /root/logger.py -t KILL -s FAIL -m "Production Image Deployed" -i $ZEPHYR_BUILD_ID -b broker -p 5555
		exit 1
	else
		python /root/logger.py -t INFO -s OK -m "Production Image Deployed" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	fi
else
	mkdir -p /root/prod/nrf52_nitrogen/samples/shell
	cd /root/zephyr-project
	source zephyr-env.sh
	python /root/logger.py -t INFO -s OK -m "Production Image Builds Started" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	echo "CONFIG_FLASH_BASE_ADDRESS=0x00008020" >> /root/zephyr-project/boards/nrf52_nitrogen/nrf52_nitrogen_defconfig
	make -C samples/shell/microkernel BOARD=nrf52_nitrogen O=/root/prod/nrf52_nitrogen/samples/shell -j 100
	if [ $? -ne 0 ]; then
		python /root/logger.py -t KILL -s FAIL -m "Production Images Built" -i $ZEPHYR_BUILD_ID -b broker -p 5555
		exit 1
	else
		python /root/logger.py -t INFO -s OK -m "Production Images Build" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	fi 

	# Sign Production Images
	python /root/logger.py -t INFO -s OK -m "Signing Production Images Started" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	python /root/zep2newt.py --bin /root/prod/nrf52_nitrogen/samples/shell/zephyr.bin --out /root/prod/nrf52_nitrogen/samples/shell/zephyr-unsigned-dfu.bin
	if [ $? -ne 0 ]; then
		python /root/logger.py -t KILL -s FAIL -m "Unsigned Production Images Built" -i $ZEPHYR_BUILD_ID -b broker -p 5555
		exit 1
	else
		python /root/logger.py -t INFO -s OK -m "Unsigned Production Images Built" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	fi

	python /root/zep2newt.py --bin /root/prod/nrf52_nitrogen/samples/shell/zephyr.bin --key /root/image_sign.pem --sig RSA --out /root/prod/nrf52_nitrogen/samples/shell/zephyr-signed-dfu.bin
	if [ $? -ne 0 ]; then
		python /root/logger.py -t KILL -s FAIL -m "Signed Production Images Built" -i $ZEPHYR_BUILD_ID -b broker -p 5555
		exit 1
	else
		python /root/logger.py -t INFO -s OK -m "Signed Production Images Built" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	fi  

	# Publish Production Images
	python /root/logger.py -t INFO -s OK -m "Production Image Publishing Started" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	cd /root/prod
	rsync -avm --include='*.bin' --include='*.log' --include='*.hex' -f 'hide,! */' . $ZEPHYR_OUTDIR
	if [ $? -ne 0 ]; then
		python /root/logger.py -t KILL -s FAIL -m "Production Images Published" -i $ZEPHYR_BUILD_ID -b broker -p 5555
		exit 1
	else
		python /root/logger.py -t INFO -s OK -m "Production Images Published" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	fi

	# Test Production Images
	python /root/logger.py -t INFO -s OK -m "Production Image Testing Started" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	sleep 5
	python /root/logger.py -t TEST -s PASS -m "test-shell : main" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	echo "test-shell : main : pass" >> /mnt/artifacts/$ZEPHYR_BUILD_ID/nrf52_nitrogen/results.txt
	if [ $? -ne 0 ]; then
		python /root/logger.py -t KILL -s FAIL -m "Production Image Tests" -i $ZEPHYR_BUILD_ID -b broker -p 5555
		exit 1
	else
		python /root/logger.py -t INFO -s OK -m "Production Image Tests" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	fi

	python /root/logger.py -t INFO -s OK -m "Automated Building and Testing Finished" -i $ZEPHYR_BUILD_ID -b broker -p 5555

	# Deploy to Hawkbit
	python /root/logger.py -t INFO -s OK -m "Deploying Production Images to Device Management System" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	python /root/hawkbit.py -p "Linaro" -n "Unsigned Linaro IoT RPB - Nitrogen - Shell" -d "Signed Linaro IoT Reference Plaform - Nitrogen - Shell" -sv "v1.0-beta-${ZEPHYR_BUILD_ID::12}" -t os -f /root/prod/nrf52_nitrogen/samples/shell/zephyr-unsigned-dfu.bin
	python /root/hawkbit.py -p "Linaro" -n "Signed Linaro IoT RPB - Nitrogen - Shell" -d "Signed Linaro IoT Reference Plaform - Nitrogen - Shell" -sv "v1.0-beta-${ZEPHYR_BUILD_ID::12}" -t os -f /root/prod/nrf52_nitrogen/samples/shell/zephyr-signed-dfu.bin
	if [ $? -ne 0 ]; then
		python /root/logger.py -t KILL -s FAIL -m "Production Image Deployed" -i $ZEPHYR_BUILD_ID -b broker -p 5555
		exit 1
	else
		python /root/logger.py -t INFO -s OK -m "Production Image Deployed" -i $ZEPHYR_BUILD_ID -b broker -p 5555
	fi
fi

python /root/logger.py -t KILL -s OK -m "Production Images Ready for Rollout" -i $ZEPHYR_BUILD_ID -b broker -p 5555
