#!/bin/bash

jekyll build
rm -rf /tmp/fatih/blog
mkdir -p /tmp/fatih
pushd /tmp/fatih
git clone git@github.com:FatihBAKIR/fatihbakir.github.io blog
cd blog
git checkout master
rm -rf *
popd
cp -r _site/* /tmp/fatih/blog
pushd /tmp/fatih/blog
rm -f publish.sh
git add .
git commit -m "up"
git push -u origin master
popd
rm -rf /tmp/fatih/blog
