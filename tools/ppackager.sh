#! /bin/bash
## ./ppackager.sh builder.list leveldb_tag
##    or
## ./ppackager.sh builder.list      ""       tarfile.tgz
##       $0         $1                $2           $3
##
## NOTE: you must manually ssh to each buildbot to get RSA fingerprint
##       into your local known_hosts file before script works

REPO=eleveldb

#
# main
#

if [ $# == 2 ]; then
    echo "2 parameters"
    temp_path=$(mktemp)
    temp_name=$(basename $temp_path)
    echo "temp file " $temp_path
    cat <<EOF >$temp_path
rm -rf ~/$USER/$REPO
mkdir -p ~/$USER
cd ~/$USER
echo " Git start:: " \$(date)
git clone git@github.com:basho/$REPO
cd $REPO
git checkout $2
export LD_LIBRARY_PATH=.
rm ~/$USER/eleveldb_$2\*

. /usr/local/erlang-r16b02/activate

echo "Make start: " \$(date)
if which gmake
then
    if gmake -j 2 -s
    then 
       echo "Build successful."
    else
       echo "Build failed."
       exit 1
    fi
    echo "Test start: " \$(date)
    if gmake -s test >/dev/null
    then
        echo "Test successful."
    else
        echo "Test failed."
        exit 1
    fi
else
    if make -j 2 -s
    then 
       echo "Build successful."
    else
       echo "Build failed."
       exit 1
    fi
    echo "Test start: " \$(date)
    if make -s test >/dev/null
    then
        echo "Test successful."
    else
        echo "Test failed."
        exit 1
    fi
fi
echo "  Test end: " \$(date)

cd priv
cp -p ../ebin/eleveldb.beam .
md5sum eleveldb.beam eleveldb.so >md5sum.txt
tar -czf ~/$USER/eleveldb_$2_\$1.tgz eleveldb.beam eleveldb.so md5sum.txt

EOF

#
#echo "Build name: " $REPO\_$2_"\$1"
#export build_name="$REPO\_$2_\$1"
#echo "Again: $build_name"
#env


    chmod a+x $temp_path

    mkdir -p ~/builds/$REPO
    rm ~/builds/$REPO/out
    rm ~/builds/$REPO/err
    rm ~/builds/$REPO/eleveldb_$2*
    parallel --tag -a $1 --gnu --colsep '[ ]{1,}' scp $temp_path buildbot@{1}:~/.  >>~/builds/$REPO/out 2>>~/builds/$REPO/err
    parallel --tag -a $1 --gnu --colsep '[ ]{1,}' ssh -q buildbot@{1} ./$temp_name {2} >>~/builds/$REPO/out 2>>~/builds/$REPO/err
    parallel --tag -a $1 --gnu --colsep '[ ]{1,}' ssh -q buildbot@{1} rm $temp_name >>~/builds/$REPO/out 2>>~/builds/$REPO/err
    parallel --tag -a $1 --gnu --colsep '[ ]{1,}' scp -q buildbot@{1}:~/$USER/eleveldb_$2\* ~/builds/$REPO/.
    echo "done"
    rm $temp_path

    grep 'Test successful.' ~/builds/$REPO/out
    grep 'Test successful.' ~/builds/$REPO/out | wc -l
    echo "Packager count: " $(wc -l $1)
elif [ $# == 3 ]; then
    echo "3 parameters"
else
    echo " ./ppackager.sh leveldb_tag"
    echo "    or"
    echo " ./ppackager.sh builder.list \"\" tarfile.tgz"
fi

exit 0
