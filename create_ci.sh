#!/bin/bash

if [ "$1" = "-h" ]; then
    echo "Usage:"
    echo "   $0 <new_azure_deploy> <old_azure_deploy> <variable_name> <script_dir> <entry_script> [<parameter>]*"
    exit 0
fi

new_azure_deploy=$1
shift
old_azure_deploy=$1
shift
variable_name=$1
shift
script_dir=$1
shift
entry_script=$1
shift
echo "new_azure_deploy=$new_azure_deploy"
echo "old_azure_deploy=$old_azure_deploy"
echo "variable_name=$variable_name"
echo "script_dir=$script_dir"
echo "entry_script=$entry_script"

if [ -e $new_azure_deploy ]; then
    echo "ERROR: new file already exists"
    exit 1
fi

script_name="cloudinit_$(date +"%Y-%m-%d_%H-%M-%S")"

makeself --base64 $script_dir ${script_name}.sh "Cloudinit script" ./$entry_script

sed -i '1d;4d' ${script_name}.sh

echo "[concat('#!/bin/bash" >${script_name}.str
echo -n "set --'," >>${script_name}.str

while test $# -gt 0
do
    echo -n "' \"',parameters('$1'),'\"'," >>${script_name}.str
    shift
done
echo "'" >>${script_name}.str
echo -n "','" >>${script_name}.str
sed "s/'/''/g" ${script_name}.sh >>${script_name}.str 
echo -n "')]" >>${script_name}.str

jq ".variables.${variable_name} = $(jq -Rs '.' <${script_name}.str)" $old_azure_deploy >$new_azure_deploy

rm ${script_name}.sh ${script_name}.str
