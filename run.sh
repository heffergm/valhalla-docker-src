#!/bin/bash

docker run \
  --name valhalla \
  -h valhalla \
  -p 8080:8080 \
  heffergm/valhalla
