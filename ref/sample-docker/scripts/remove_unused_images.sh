#!/usr/bin/env bash

docker images -q | xargs docker rmi

exit 0
