#!/bin/bash

IMAGE_DIR="./img"
for dir in $(ls $IMAGE_DIR); do
  if [ -d "$IMAGE_DIR/$dir" ]; then
    echo "Building image: $dir"
    docker build -t "localhost:32000/$dir:latest" "$IMAGE_DIR/$dir"
    echo "Pushing image: $dir"
    docker push "localhost:32000/$dir:latest"
  fi
done