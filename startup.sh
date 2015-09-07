#!/bin/bash



nginx -c /etc/nginx/nginx.conf
exec /usr/bin/supervisord -n
