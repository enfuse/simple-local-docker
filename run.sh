#!/bin/bash
docker run -ti -h dev.local \
           -v "$PWD/..":/var/www \
           -v "$PWD/database":/var/lib/mysql \
           -p 0.0.0.0:80:80 \
	   -p 0.0.0.0:2222:22 \
           -p 0.0.0.0:443:443 \
           -p 0.0.0.0:3306:3306 \
           -p 0.0.0.0:9000:9000 \
	   -p 0.0.0.0:8025:8025 \
            drupaldev
