#!/bin/bash

for i in $(docker compose ps | grep app | awk '{print $1;}' | sed 's/^.*-//'); do
  if docker compose logs --tail 200 --index ${i} app | grep 'Make sure that your application is loading Devise and Warden'; then
    echo "docker stop docker-app-${i}"
    docker stop docker-app-${i}
    echo "docker rm docker-app-${i}"
    docker rm docker-app-${i}
  else
    echo "index ${i} seems stable."
  fi
done
echo dc up -d
docker compose up -d