#/bin/bash

source ~/azurehpc/install.sh

echo "running from $(pwd)"

echo "moving up one directory"
cd ..

echo "trying the copy"
azhpc-scp -- -r 'hpcadmin@headnode:results-*' .

