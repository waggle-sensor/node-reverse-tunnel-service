#!/bin/bash -e

if [ "$(uname)" == "Darwin" ]; then
  docker run -ti --rm -v `pwd`:/workdir -w /workdir ubuntu:20.04 /bin/bash -c "apt-get update && apt-get install -y git && ./release.sh $@"
  exit 0
fi

# determine full version
VER_LONG=$(git describe --tags --long | cut -c2-)
echo "VER_LONG: ${VER_LONG}"
# note that the first character "v" had to be stripped, debian requires version numbers to start with digit
# (git convention is to use a "v" as prefix in the version number)
# example (without "v"): 2.1.1-2-g146e8fc


VER_SHORT=$(echo ${VER_LONG} | cut -d '-' -f 1)
echo "VER_SHORT: ${VER_SHORT}"
# example: 2.1.1

REL_COMMIT_COUNT=$(echo ${VER_LONG} | cut -d '-' -f 2)
echo "REL_COMMIT_COUNT: ${REL_COMMIT_COUNT}"
# if this is not 0, do not do a release
# example: 2


if [[ ( "${REL_COMMIT_COUNT}_" != "0_" ) && "$1_" != "--force_" ]] ; then
    echo ""
    echo "Error:"
    echo "  The current git commit has not been tagged. Please create a new tag first to ensure a proper unique version number."
    echo "  Use --force to ignore error (for debugging only)"
    echo ""
    exit 1
fi



VER_HASH=$(echo ${VER_LONG} | cut -d '-' -f 1)
echo "VER_SHASH: ${VER_HASH}"


# Build the reverse tunnel debian package
BASEDIR=/tmp/reverse
NAME=waggle-bk-reverse-tunnel
ARCH=all

mkdir -p ${BASEDIR}/DEBIAN
cat > ${BASEDIR}/DEBIAN/control <<EOL
Package: ${NAME}
Version: ${VER_LONG}
Maintainer: sagecontinuum.org
Description: Establish reverse SSH tunnel to Beehive
Architecture: ${ARCH}
Priority: optional
EOL

cp -p deb/reverse/postinst ${BASEDIR}/DEBIAN/
cp -p deb/reverse/prerm ${BASEDIR}/DEBIAN/

mkdir -p ${BASEDIR}/etc/systemd/system
mkdir -p ${BASEDIR}/usr/bin
cp -p ./waggle-bk-reverse-tunnel.service ${BASEDIR}/etc/systemd/system/
sed -e "s/{{VERSION}}/${VER_LONG}/; w ${BASEDIR}/usr/bin/waggle-bk-reverse-tunnel.sh" ./waggle-bk-reverse-tunnel.sh
chmod +x ${BASEDIR}/usr/bin/waggle-bk-reverse-tunnel.sh

dpkg-deb --root-owner-group --build ${BASEDIR} "${NAME}_${VER_SHORT}_${ARCH}.deb"
