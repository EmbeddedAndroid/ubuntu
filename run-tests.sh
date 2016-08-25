#!/bin/bash

echo "Fetching LAVA API Key Started $(date +"%T")" >> /var/www/html/seq.txt
wget http://lava/tmp/apikey.txt
echo "Fetching LAVA API Key Finished $(date +"%T")" >> /var/www/html/seq.txt
echo "Running Tests Started $(date +"%T")" >> /var/www/html/seq.txt
sed -i -e "s/localhost/$(hostname -I | tr -d '[[:space:]]')/g" *.yaml
./submityaml.py -k apikey.txt -p aes128-test.yaml
echo "Running Tests Finished $(date +"%T")" >> /var/www/html/seq.txt
cat results.txt >> /var/www/html/seq.txt
