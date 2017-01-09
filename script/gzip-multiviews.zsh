#!/bin/zsh

for f in "$@"; do
    if [[ $f:e == "gz" ]]; then
	echo skipping $f
	continue
    fi
    cp -va $f $f.$f:e &&
    gzip -9 $f &&
    cp -a $f.$f:e $f
done
