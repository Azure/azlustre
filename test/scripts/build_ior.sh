#!/bin/bash
APP_NAME=ior
SHARED_APP=${SHARED_APP:-/apps}
MODULE_DIR=${SHARED_APP}/modulefiles
MODULE_NAME=${APP_NAME}
PARALLEL_BUILD=8
IOR_VERSION=3.2.1
INSTALL_DIR=${SHARED_APP}/${APP_NAME}-$IOR_VERSION

source /etc/profile.d/modules.sh # so we can load modules
export MODULEPATH=/usr/share/Modules/modulefiles:$MODULE_DIR
module load gcc-9.2.0
module load mpi/impi_2018.4.274

module list
function create_modulefile {
mkdir -p ${MODULE_DIR}
cat << EOF > ${MODULE_DIR}/${MODULE_NAME}
#%Module
prepend-path    PATH            ${INSTALL_DIR}/bin;
prepend-path    LD_LIBRARY_PATH ${INSTALL_DIR}/lib;
prepend-path    MAN_PATH        ${INSTALL_DIR}/share/man;
setenv          IOR_BIN         ${INSTALL_DIR}/bin
EOF
}

cd $SHARED_APP
IOR_PACKAGE=ior-$IOR_VERSION.tar.gz
wget https://github.com/hpc/ior/releases/download/$IOR_VERSION/$IOR_PACKAGE
tar xvf $IOR_PACKAGE
rm $IOR_PACKAGE

cd ior-$IOR_VERSION

CC=`which mpicc`
./configure --prefix=${INSTALL_DIR}
make -j ${PARALLEL_BUILD}
make install

create_modulefile
