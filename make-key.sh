#!/bin/bash

set -e
set -u


SYN="
	$0 ENV TARGET_DIR

Creates a key pair and address in the directory named TARGET_DIR

ENV		Either 'testnet' or 'mainnet' depending on what env you want to
TARGET_DIR 	The directory to create the keys in. This directory must already exist

"

[ $# -ne 2 ] && echo "$SYN" && exit 1
[ ! -d $2 ] && echo "$SYN" && exit 1

case $1 in
  testnet)
    NET="--testnet-magic 1097911063"
    ;;
  mainnet)
    NET="--mainnet"
    ;;
  *)
    echo "$SYNTAX"
    exit 1
    ;;
esac

DIR=$2

SIG_KEY="$DIR/skey"
VER_KEY="$DIR/vkey"
ADDR="$DIR/addr"

cardano-cli address key-gen \
	--verification-key-file "$VER_KEY" \
	--signing-key-file "$SIG_KEY"

cardano-cli address build \
	--payment-verification-key-file "$VER_KEY" \
	$NET \
	--out-file $ADDR

echo "
{
  \"sig\": `cat $SIG_KEY`,
  \"ver\": `cat $VER_KEY`,
  \"addr\": \"`cat $ADDR`\"
}
"

