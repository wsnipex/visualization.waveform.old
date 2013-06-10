#!/bin/bash

#RELEASEV=${RELEASEV:-"auto"}
BRANCH=${BRANCH:-"master"}
TAG=${TAG:-"1"}
WORK_DIR=${WORKSPACE:-$(pwd)}
[[ $(which lsb_release) ]] && DISTS=${DISTS:-$(lsb_release -cs)} || DISTS=${DISTS:-"stable"}
ARCHS=${ARCHS:-$(dpkg --print-architecture)}
BUILDER=${BUILDER:-"debuild"}
DEBUILD_OPTS=${DEBUILD_OPTS:-""}
PDEBUILD_OPTS=${PDEBUILD_OPTS:-""}
PBUILDER_BASE=${PBUILDER_BASE:-"/var/cache/pbuilder"}
DPUT_TARGET=${DPUT_TARGET:-"local"} 

declare -A ALL_ADDONS=(
    ["visualization.waveform"]="https://github.com/wsnipex/visualization.waveform/archive/${BRANCH}.tar.gz"
    #["foobar"]="https://github.com/cptspiff/visualization.waveform/archive/${BRANCH}.foo"
)

ADDONS=${ADDONS:-${!ALL_ADDONS[@]}}


function usage {
    echo "$0: this script builds xbmc addon debian packages."
    echo "The build is controlled by ENV variables, which van be overridden as appropriate:"
    echo "BUILDER is either debuild(default) or pdebuild(needs a proper pbuilder setup)"
    checkEnv
    exit 2
}

function checkEnv {
    echo "#------ build environment ------#"
    echo "Building following addons: $ADDONS"
    echo "WORK_DIR: $WORK_DIR"
    #echo "RELEASEV: $RELEASEV"
    [[ -n $TAG ]] && echo "TAG: $TAG"
    echo "DISTS: $DISTS"
    echo "ARCHS: $ARCHS"
    echo "BUILDER: $BUILDER"
    echo "CONFIGURATION: $Configuration"

    if ! [[ $(which $BUILDER) ]]
    then
        echo "Error: can't find ${BUILDER}, consider using full path to [debuild|pdebuild]"
        exit 1
    fi

    if [[ "$BUILDER" =~ "pdebuild" ]]
    then
        if ! [[ -d $PBUILDER_BASE ]] ; then echo "Error: $PBUILDER_BASE does not exist"; exit 1; fi
        echo "PBUILDER_BASE: $PBUILDER_BASE"
        echo "PDEBUILD_OPTS: $PDEBUILD_OPTS"
    else
        echo "DEBUILD_OPTS: $DEBUILD_OPTS"
    fi

    echo "#-------------------------------#"
}

function buildDebianPackages {
    for dist in $DISTS
    do
        sed "s/#DIST#/${dist}/g" debian/changelog.tmp > debian/changelog
        dch --release  ""
        for arch in $ARCHS
        do
            echo "building: DIST=$dist ARCH=$arch"
            if [[ "$BUILDER" =~ "pdebuild" ]]
            then
                DIST=$dist ARCH=$arch $BUILDER $PDEBUILD_OPTS
                [ $? -eq 0 ] || exit 1
            else
                $BUILDER $DEBUILD_OPTS
                echo "output directory: $WORK_DIR/.."
            fi
        done
    done
} 

function prepareBuild {
    for addon in ${ADDONS[*]}
    do
        cd $WORK_DIR || exit 1
        url=${ALL_ADDONS["$addon"]}
        [ -d ${addon}.tmp ] && rm -rf ${addon}.tmp
        mkdir ${addon}.tmp && cd ${addon}.tmp || exit 1
        wget $url
        tar xzf ${BRANCH}.tar.gz
        PACKAGENAME=$(awk '{if(NR==1){ print $1}}' ${addon}-${BRANCH}/debian/changelog.in)
        PACKAGEVERSION=$(awk -F'=' '!/<?xml/ && /version/ && !/>/ {gsub("\"",""); print $2}' ${addon}-${BRANCH}/addon/addon.xml)
        mv ${BRANCH}.tar.gz ${PACKAGENAME}_${PACKAGEVERSION}.orig.tar.gz
        cd ${addon}-${BRANCH} 
        sed -e "s/#PACKAGEVERSION#/${PACKAGEVERSION}/g" -e "s/#TAGREV#/${TAG}/g" debian/changelog.in > debian/changelog.tmp
        buildDebianPackages
        cd .. && uploadPkg
        #ls -l ../${PACKAGENAME}_${PACKAGEVERSION}-${TAG}*.changes
        #rm -rf $addon.tmp
    done

}

function uploadPkg {
    local changes="${PACKAGENAME}_${PACKAGEVERSION}-${TAG}*.changes"
    if [[ "$BUILDER" =~ "pdebuild" ]]
    then
        PKG="${PBUILDER_BASE}/${dist}-${arch}/result/${changes}"
        echo "signing package"
        debsign $PKG
        echo "uploading $PKG to $DPUT_TARGET"
        dput $DPUT_TARGET $PKG
        UPLOAD_DONE=$?
    else
        ls -l $changes
    fi
}

function cleanup {
    if [[ $UPLOAD_DONE -eq 0 ]] && [[ "$BUILDER" =~ "pdebuild" ]]
    then
        cd $WORK_DIR/.. || exit 1
        rm ${DEST}*
        rm ${DEST/-/_}*
    fi
}

###
# main
###
if [[ $1 = "-h" ]] || [[ $1 = "--help" ]]
then
    usage
    exit
fi

checkEnv
prepareBuild
#cleanup

