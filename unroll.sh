#!/bin/bash

part=root
if [ "x$1" == "x" ]; then
	part=$1
fi

mkdir $part
sudo tar xJf data/$part.tar.xz -C $part
