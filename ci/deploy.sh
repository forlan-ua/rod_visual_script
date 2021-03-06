#!/bin/bash

DIR=$(pwd)
cd $(dirname $0)/..
WORKDIR=$(pwd)

NIMBLE_INSTALL="nimble install variant -y"
COMPILE="nim c --run -d:release --nimcache:/tmp/nimcache visual_script_tests"

docker run --rm -it -v "$WORKDIR:/visual_script" -w "/visual_script" forlanua/nim:ce1bd913cf036a57cff31e36c9e850316076649e /bin/bash -c "$NIMBLE_INSTALL && cd tests && $COMPILE"

RESULT=$?
if [ "$RESULT" != "0" ]; then
    exit $RESULT
fi

LAST_VERSION=$(git ls-remote https://github.com/forlan-ua/nim-visual-script master | sed "s/refs\/heads\/master//" | tr -d '[:space:]')
CUR_VERSION=$(git rev-parse HEAD)
if [ "$LAST_VERSION" != "$CUR_VERSION" ]; then
    echo "Non the last master commit. Skip auto tagging."
    exit 0
fi


git tag -l | xargs git tag -d
git fetch --tags


if [ ! -z "$(git tag --points-at $CUR_VERSION)" ]; then
    echo "Commit has been already tagged"
    exit 0
fi

set -f

mkdir -p ~/.ssh
rm -rf ~/.ssh/id_rsa
KEY=$(echo $GITHUB_KEY | sed "s/|/\\\n/g")
echo -e $KEY > ~/.ssh/id_rsa
chmod 400 ~/.ssh/id_rsa

# ssh-add ~/.ssh/id_rsa
ssh-keyscan github.com >> ~/.ssh/known_hosts

git config --global user.email "builds@travis-ci.com"
git config --global user.name "Travis CI"
git remote remove origin
git remote add origin git@github.com:forlan-ua/nim-visual-script.git

RESULT=$?
if [ "$RESULT" != "0" ]; then
    exit $RESULT
fi

OLDTAG=
for tag in $(git tag --list 'v*' --sort=-v:refname); do
    OLDTAG="$tag"
    break
done

echo "Old tag: $OLDTAG"

PARTS=(${OLDTAG//\./ })
NEWTAG="${PARTS[0]}.${PARTS[1]}.$((${PARTS[2]}+1))"
DATE=$(date -u +"%F %H:%M:%S UTC")
MESSAGE="Release date $DATE"

git tag -a "$NEWTAG" -m "$MESSAGE"

echo "New tag: $NEWTAG. With message \`$MESSAGE\`"

git push --tags

RESULT=$?
if [ "$RESULT" != "0" ]; then
    exit $RESULT
fi