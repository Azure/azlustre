#!/bin/bash

./create_ci.sh \
    azuredeploy.json \
    azuredeploy_template.json \
    ciScript \
    packer/lustre-setup-scripts \
    setup_lustre.sh \
    name \
    storageAccount \
    storageKey \
    storageContainer \
    logAnalyticsAccount \
    logAnalyticsWorkspaceId \
    logAnalyticsKey \
    ossDiskSetup
