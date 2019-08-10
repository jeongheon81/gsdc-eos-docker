#!/bin/bash

[ -f /usr/bin/eos ] || alias eos='docker exec -it $(docker ps --format "{{.Names}}" | grep eos-mgm | head -n 1) eos'
alias ed-eos='docker exec -it $(docker ps --format "{{.Names}}" | grep eos-mgm | head -n 1) eos'
alias ed-enter='docker exec -it $(docker ps --format "{{.Names}}" | grep eos-mgm | head -n 1) /bin/bash'
alias eos-docker-clean='docker stop $(docker ps -aq)> /dev/null 2>&1;docker rm $(docker ps -aq)> /dev/null 2>&1;docker rmi -f $(docker images -q) > /dev/null 2>&1'
