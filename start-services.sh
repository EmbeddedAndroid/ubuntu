#!/bin/bash
service apache2 restart
cd /srv/mirrors/zephyr-mirror
git remote update
