#!/bin/bash

docker build -t otus-simple-nginx ./
docker run --rm -ti -p 8080:80 --name otus-simple-nginx otus-simple-nginx
