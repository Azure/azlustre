#!/bin/bash

ethtool -L eth1 tx 8 rx 8 && ifconfig eth1 down && ifconfig eth1 up
