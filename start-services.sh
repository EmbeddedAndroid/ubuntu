#!/bin/bash
echo "Apache Init Started $(date +"%T")" >> /var/www/html/seq.txt
service apache2 restart
echo "Apache Init Finished $(date +"%T")" >> /var/www/html/seq.txt
cd /srv/mirrors/zephyr-mirror
echo "Source Mirror Update Started $(date +"%T")" >> /var/www/html/seq.txt
git remote update
echo "Source Mirror Update Finished $(date +"%T")" >> /var/www/html/seq.txt
