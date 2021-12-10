#!/bin/bash

VERSION=$1

cp azuredeploy.json mainTemplate.json

rm azurehpc-lustre-fs-${VERSION}.zip
zip azurehpc-lustre-fs-${VERSION}.zip mainTemplate.json createUiDefinition.json
cp azurehpc-lustre-fs-${VERSION}.zip ~/onedrive/Documents/.

