#!/bin/bash

# This generates the embedded scripts for the createUiDefinition file

echo "virtualNetork constraints.allowedValues:"
echo
echo $(cat <<EOF
[
    map(
        filter(
            basics('getVnetName').value,
            (item) => contains(item.location, location())
        ), 
        (item) => parse(
            concat(
                '{\"label\":\"', 
                item.name, 
                '\", \"description\":\"', 
                substring(
                    item.id, 
                    add(indexOf(item.id, 'resourceGroups/'), 15), 
                    sub(
                        indexOf(item.id, '/providers'), 
                        add(indexOf(item.id, 'resourceGroups/'), 15)
                    )
                ),
                '\", \"value\":\"', 
                item.id, 
                '\"}'
            )
        )
    )
]
EOF
)
echo

echo "subnet constraints.allowedValues:"
echo
echo $(cat <<EOF
[
    map(
        first(
            map(
                filter(
                    basics('getVnetName').value,
                    (item) => equals(item.id, basics('vnet'))
                ),
                (item) => item.properties.subnets
            )
        ),
        (item) => parse(
            concat(
                '{\"label\":\"', 
                item.name,                 
                '\", \"value\":\"', 
                item.name, 
                '\"}'
            )
        )
    )
]
EOF
)
echo

echo "output - existingVnetResourceGroupName"
echo
echo $(cat <<EOF
[
    substring(
        basics('vnet'), 
        add(indexOf(basics('vnet'), 'resourceGroups/'), 15), 
        sub(
            indexOf(basics('vnet'), '/providers'), 
            add(indexOf(basics('vnet'), 'resourceGroups/'), 15)
        )
    )
]
EOF
)
echo

echo "output - existingVnetName"
echo
echo $(cat <<EOF
[
    substring(
        basics('vnet'), 
        add(lastIndexOf(basics('vnet'), '/'), 1),
        sub(
            length(basics('vnet')),
            add(lastIndexOf(basics('vnet'), '/'), 1)
        )
    )
]
EOF
)
echo