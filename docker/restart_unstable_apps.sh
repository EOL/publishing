#!/bin/bash

for i in $(docker compose ps | grep docker-app | awk '{print $1;}' | sed 's/^.*-//'); do
  echo "Index ${i}:"
  if docker compose logs --tail 200 --index ${i} app | grep 'Make sure that your application is loading Devise and Warden'; then
    echo "Devise error, will restart docker-app-${i}"
    docker stop docker-app-${i}
    docker rm docker-app-${i}
  elif docker compose logs --tail 200 --index ${i} app | grep 'rake neo4j:migrate'; then
    echo "Neo4j error, will restart docker-app-${i}"
    docker stop docker-app-${i}
    docker rm docker-app-${i}
  else
    echo "index ${i} seems stable."
  fi
done
echo dc up -d
docker compose up -d