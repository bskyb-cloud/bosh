#!/bin/bash

# pid number for temp directory
BASH_PID=$$
# temporary directory number
TMP_DIR="version-updater-tmp.$$"
#date of the stemcell
STEMCELL_DATE="`date +%y%m%d%H%M`"

if [ -z $1 ];
then
	echo "usage: $0 <path/to/stemcell>"
	exit
fi

NEW_STEMCELL_NAME=`basename $1 | sed "s/-\([0-9]*\)-/-\1.$STEMCELL_DATE-/g"`
EXISTING_STEMCELL_DIR=`dirname $1`

# make the directory
mkdir -p $TMP_DIR

#untar the stemcell file
echo "untarring..."
tar xf $1 -C $TMP_DIR

pushd $TMP_DIR >> /dev/null
echo "updating stemcell version..."
cat stemcell.MF | sed "s/version\:\ '\([0-9]*\)'/version\:\ '\1.$STEMCELL_DATE'/g" > stemcell.updated.MF
mv stemcell.updated.MF stemcell.MF

echo "tarring..."
tar czf $NEW_STEMCELL_NAME *
popd >> /dev/null

mv $TMP_DIR/$NEW_STEMCELL_NAME $EXISTING_STEMCELL_DIR

echo "cleaning up..."
rm -rf $TMP_DIR
