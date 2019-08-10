#!/usr/bin/env bash

n_fst=7

[[ $# -ne 0 ]] && n_fst=$1

# Enable default space with quota disabled
eos -b space set default on
eos -b space quota default off

echo "Wait for FSTs to become online ..."

for i in `seq 1 30`; do
  if [ `eos fs ls | grep online | wc -l` -eq $n_fst ]; then
    echo "All FSTs are online"
    break
  else
    sleep 1
  fi
done

if [ `eos fs ls | grep online | wc -l` -ne $n_fst ]; then
    echo "Some of the FSTs are not online ... aborting!"
    eos fs ls
    exit 1;
fi

# Boot filesystems
eos -b fs boot \*
eos -b config save default -f

echo "Wait for FSTs to boot ..."

for i in `seq 1 60`; do
  if [ `eos fs ls | grep booted | wc -l` -eq $n_fst ]; then
    echo "All FSTs are booted"
    break
  else
    sleep 1
  fi
done

if [ `eos fs ls | grep booted | wc -l` -ne $n_fst ]; then
    echo "Some of the FSTs are not booted ... aborting!"
    eos fs ls
    exit 1;
fi
