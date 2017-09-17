+#!/bin/bash
 +http_proxy=http://192.168.0.112:8888 apt-get update
 +http_proxy=http://192.168.0.112:8888 apt-get install --yes apache2
 +echo "syncCompletE" > /var/www/html/ping.html
 +