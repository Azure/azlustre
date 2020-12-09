#!/bin/bash

resource_group=$1
vmss=$2
output_file=$3

az vmss list-instances --resource-group $resource_group --name $vmss -o tsv --query [].osProfile.computerName | tee $output_file
