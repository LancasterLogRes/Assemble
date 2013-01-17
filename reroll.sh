#!/bin/bash

mv data/root.tar.xz /tmp
sudo tar cC root . | xz -- > data/root.tar.xz
sudo rm -rf root
