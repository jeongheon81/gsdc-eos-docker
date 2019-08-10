#!/bin/bash

if [ ! -z $ED_NODE_TYPE ];then
    export PS1="[\u@\h (eos-docker \$ED_NODE_TYPE) \W]# "
fi
