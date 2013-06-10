#!/bin/bash

RELEASEV=${RELEASEV:-"auto"}
BRANCH=${BRANCH:-"master"}
TAG=${TAG:-"1"}
REPO_DIR=${WORKSPACE:-$(cd "$(dirname $0)/../../../" ; pwd)}
[[ $(which lsb_release) ]] && DISTS=${DISTS:-$(lsb_release -cs)} || DISTS=${DISTS:-"stable"}
ARCHS=${ARCHS:-$(dpkg --print-architecture)}
BUILDER=${BUILDER:-"debuild"}
DEBUILD_OPTS=${DEBUILD_OPTS:-""}
PDEBUILD_OPTS=${PDEBUILD_OPTS:-""}
PBUILDER_BASE=${PBUILDER_BASE:-"/var/cache/pbuilder"}
DPUT_TARGET=${DPUT_TARGET:-"local"} 

declare -A ALL_ADDONS=(
    ["visualization.waveform"]="https://github.com/wsnipex/visualization.waveform/archive/${BRANCH}.tar.gz"
    ["foobar"]="https://github.com/cptspiff/visualization.waveform/archive/${BRANCH}.foo"
)

ADDONS=${ADDONS:-${!ALL_ADDONS[@]}}


function buildDebianPackages {
    archiveRepo
    cd $REPO_DIR || exit 1
    sed -e "s/#PACKAGEVERSION#/${packageversion}/g" -e "s/#TAGREV#/${TAG}/g" debian/changelog.in > debian/changelog.tmp

    for dist in $DISTS
    do
        sed "s/#DIST#/${dist}/g" debian/changelog.tmp > debian/changelog
        for arch in $ARCHS
        do
            cd $REPO_DIR
            echo "building: DIST=$dist ARCH=$arch"
            if [[ "$BUILDER" =~ "pdebuild" ]]
            then
                DIST=$dist ARCH=$arch $BUILDER $PDEBUILD_OPTS
                [ $? -eq 0 ] && uploadPkg || exit 1
            else
                $BUILDER $DEBUILD_OPTS
                echo "output directory: $REPO_DIR/.."
            fi
        done
    done
} 

for addon in ${ADDONS[*]}
do
    url=${ALL_ADDONS["$addon"]}
    [ -d ${addon}.tmp ] && rm -rf ${addon}.tmp
    mkdir ${addon}.tmp && cd ${addon}.tmp || exit 1
    wget $url
    tar xzf ${BRANCH}.tar.gz
    #cd ${addon}*
    packagename=$(awk '{if(NR==1){ print $1}}' ${addon}-${BRANCH}/debian/changelog.in)
    packageversion=$(awk -F'=' '!/<?xml/ && /version/ && !/>/ {gsub("\"",""); print $2}' ${addon}-${BRANCH}/addon/addon.xml)
    #cd ..
    mv ${BRANCH}.tar.gz ${packagename}_${packageversion}.orig.tar.gz
    cd ${addon}-${BRANCH}
    buildDebianPackages
    #debuild
    #rm -rf $addon.tmp
done






