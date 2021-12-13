#!/bin/bash

VERSION=$1

./build.sh
cp azuredeploy.json mainTemplate.json

rm -f azurehpc-lustre-fs-${VERSION}.zip
zip azurehpc-lustre-fs-${VERSION}.zip mainTemplate.json createUiDefinition.json

