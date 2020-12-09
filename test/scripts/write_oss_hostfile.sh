#!/bin/bash

for i in {0..9} {a..z}; do echo "lustre00000${i}"; done > oss
for i in {0..9} {a..z}; do echo "lustre00001${i}"; done >> oss
for i in {0..9} {a..z}; do echo "lustre00002${i}"; done >> oss
for i in {0..9} {a..z}; do echo "lustre00003${i}"; done >> oss
pssh -l lustre -h oss hostname 2>/dev/null | grep SUCCESS |sed 's/.*\[SUCCESS\] //g' | sort | tee oss.real && mv oss.real oss


