#!/bin/bash

usage()
{
    echo "Usage: adpl_install [-o orch_ip] [-h]"
    exit 1
}

orch_ip=""
attr='ORCHURL='
cmd="dpkg -i avocado_1.0.*_amd64.deb"

if [ "$#" -gt 2 ] || [ "$#" -eq 0 ]; then
	usage
fi

while getopts ":ho:" opt; do
  case ${opt} in
    h ) # process option a
	echo "-o <ip/hostname> orchestrator IP/hostname"
	echo "-h help"
	exit 1
      ;;
    o ) # process option l
    orch_ip=$2
     ;;
    \? )
	usage
	exit 1
      ;;
    :)
    echo "Option -$OPTARG requires an argument."
    usage 
    exit 1    
  esac

echo "*********************************************************************
* Copy rights : Avocado Systems Inc. 2015
*********************************************************************"
echo ""
echo "Installing Libraries..."
echo ""
echo ""

h="https://"
h+=$orch_ip
h+=":8443/orchestrator/"
attr+=$h
#echo $attr
export $attr

env | grep ORCH
list="ls -lRt /usr/avcd/"
$cmd
$list
done