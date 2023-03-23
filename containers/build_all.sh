#!/bin/bash

for f in *.def
do
  n=${f%.def}
  sif="$n.sif"
  if [ ! -f "$sif" ]; then
    echo "## $sif container does not exist. ##"
    echo "## Starting build!!! ##"
    singularity build --force --fakeroot $sif $f
  else
    echo "$sif container already exists. Will not rerun!"
  fi
done

echo "Done building all containers"
