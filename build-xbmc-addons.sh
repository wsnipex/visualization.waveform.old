#!/bin/bash

RELEASEV=${RELEASEV:-"auto"}
BRANCH=${BRANCH:-"master"}
TAG=${TAG}
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


for addon in ${ADDONS[*]}
do
    url=${ALL_ADDONS["$addon"]}
    [ -d ${addon}.tmp ] && rm -rf ${addon}.tmp
    mkdir ${addon}.tmp && cd ${addon}.tmp || exit 1
    wget $url
    tar xzf ${BRANCH}.tar.gz
    cd ${addon}* 
    debuild
    #rm -rf $addon.tmp
done
