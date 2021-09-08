#!/bin/bash

./create_ci.sh \
    azuredeploy.json \
    azuredeploy_template.json \
    ciScript \
    scripts \
    setup_lustre.sh \
    name \
    instanceCount \
    storageAccount \
    storageSas \
    storageContainer \
    logAnalyticsAccount \
    logAnalyticsWorkspaceId \
    logAnalyticsKey \
    ossDiskSetup
