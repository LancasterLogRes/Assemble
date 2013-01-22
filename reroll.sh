#!/bin/bash

part=root
if [ "x$1" == "x" ]; then
	part=$1
fi

mv data/$part/tmp
sudo tar cC $part . | xz -- > data/$part.tar.xz
sudo rm -rf $part
