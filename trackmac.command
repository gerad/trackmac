#! /bin/bash

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

DIR=`dirname "$0"`
cd $DIR
ruby trackmac.rb
sleep 100
