#!/bin/bash
set -e
set -u

SYNTAX="

   $0 ENV SLOTS DZ

This script creates, a policy for an NFT mint at KEY.policy.script
Arguments:

ENV	  Either 'testnet' or 'mainnet' depending on what env you want to

SLOTS	How many slots in the future should this policy be in

DZ	  The name of the dropzone to use. $0 will expect the DZ/skey, DZ/vkey
      and DZ/addr files to exist. DZ must be a directory. See 'make-key.sh' 
      for more details.
"


[ $# -ne 3 ] && echo "$SYNTAX" && exit 2

ENV=$1
SLOTS=$2
DZ=$3

case $ENV in
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

for i in skey vkey addr
do
  [ ! -f "${DZ}/$i" ] && echo "${DZ}/$i is missing!" && echo "$SYNTAX" && exit 1
done

SOURCE_ADDRESS=$(cat "${DZ}/addr")
DESTINATION_ADDRESS=${SOURCE_ADDRESS}

POLICY_SCRIPT=${DZ}/policy.script
POLICY_ID=${DZ}/policy.id
POLICY_VKEY=${DZ}/vkey
POLICY_SKEY=${DZ}/skey

KEYHASH=$(cardano-cli address key-hash --payment-verification-key-file ${POLICY_VKEY})
AFTER_SLOT=$(cardano-cli query tip $NET | jq .slot)
BEFORE_SLOT=$( expr $AFTER_SLOT + $SLOTS )

cat > ${POLICY_SCRIPT} <<EOF
{
  "type": "all",
  "scripts": 
  [
    {
      "type": "sig",
      "keyHash": "${KEYHASH}"
    },
    {
      "type": "after",
      "slot": $AFTER_SLOT
    },
    {
      "type": "before",
      "slot": $BEFORE_SLOT
    }
  ]
}
EOF

cardano-cli transaction policyid --script-file ${POLICY_SCRIPT} > $POLICY_ID

