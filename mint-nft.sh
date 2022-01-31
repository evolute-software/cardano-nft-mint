#!/usr/bin/env bash
set -e
set -u

cd `dirname $0`
SYNTAX="

   $0 ENV DZ TO_ADDR SVC_ADDR SVC_FEE_LV

This script creates, a policy for an NFT mint.
Arguments:

ENV	
  Either 'testnet' or 'mainnet' depending on what env the app is running in

DZ	
  The dropzone directory to use. $0 will expect the following files:
    DZ/skey
	  DZ/vkey
    DZ/addr
	  DZ/policy.script
    DZ/policy.id
	  DZ/nft-meta		the 721 json payload

TO_ADDR	
  Where to send the NFT to? The NFT will be paid for by the dropzone but here
	you can define who will receive the token and the rest of the funds.

SVC_ADDR
  Which address collects the service fee (SVC_FEE_LV)

SVC_FEE_LV
  How many LOVELACE the service sends itself
"

[ $# -ne 5 ] && echo "$SYNTAX" && exit 2

ENV=$1
DZ=$2
TO_ADDR=$3
PERGAMON_ADDR=$4
PERGAMON_FEE_LV=$5

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

for i in skey vkey addr policy.id policy.script nft-meta
do
  [ ! -f ${DZ}/$i ] && echo "${DZ}/$i is missing!" && echo "$SYNTAX" && exit 1
done

ERA="`../tx/get-era-flag.sh $1`"

# This script creates, signs, and submits a transaction that creates an NFT
# including META and POLICY, that will be sent to ADDR.

PAYMENT_ADDR=$(cat "${DZ}/addr")
PAYMENT_SKEY="${DZ}/skey"
TOKEN_NAMES=$( jq -r 'keys | @sh' "${DZ}/nft-meta" | xargs )
# use these like `for i in $TOKEN_NAMES; do echo $i; done`  
TOKEN_NFT_META=$(cat "${DZ}/nft-meta")
POLICY_ID=$(cat "${DZ}/policy.id")
POLICY_SCRIPT="${DZ}/policy.script"
#TX_BEFORE=$(jq '.scripts[] | select(.type == "after" ) | .slot' $POLICY_SCRIPT )
#TX_AFTER=$(jq '.scripts[] | select(.type == "before" ) | .slot' $POLICY_SCRIPT )

# Create metadata payload
META_JSON="${DZ}/full-metadata.json"

cat > ${META_JSON} <<EOF
{
  "721": 
  {
    "$POLICY_ID": 
    $TOKEN_NFT_META
  }
}
EOF



# 2. Extract protocol parameters (needed for fee calculations)
cardano-cli query protocol-parameters \
            $NET \
            --out-file ${DZ}/protparams.json

# 3. Get UTXOs from our wallet
IN_UTXO=$(cardano-cli query utxo \
                      $NET \
                      --address ${PAYMENT_ADDR} | grep -v "^ \|^-" | awk '{print "--tx-in "$1"#"$2}' | xargs)
UTXO_COUNT=$(cardano-cli query utxo \
                         $NET \
                         --address ${PAYMENT_ADDR} | grep -v "^ \|^-" | wc -l)

# 4. Calculate different tokens balances from our UTXOs
## 4.1 Cleanup tmp
rm -f ${DZ}/balance*
## 4.2 Query our address again and save output into a file
cardano-cli query utxo \
            $NET \
            --address ${PAYMENT_ADDR} | 
              sed 's/ + TxOutDatumHash[^+]*//g'  | 
              grep -v "^ \|^-" | 
              sed 's| + |\n|g' | 
              sed 's|.* \([0-9].*lovelace\)|\1|g' > ${DZ}/balances

## 4.3 Sum different tokens balances and save them on different files
awk '{print $2}' ${DZ}/balances | uniq | while read token; do grep ${token} ${DZ}/balances | gawk -M '{s+=$1} END {print s}' > ${DZ}/balance.${token}; done
OTHER_COINS=$(for balance_file in $(ls -1 ${DZ}/balance.* | grep -v lovelace); do BALANCE=$(cat ${balance_file}); TOKEN=$(echo $balance_file | sed "s#${DZ}/balance.##g"); echo +${BALANCE} ${TOKEN}; done | xargs)

TO_ADDR_LV=$(( $(cat ${DZ}/balance.lovelace) - $PERGAMON_FEE_LV ))

MINT_OUTPUTS=`for i in $TOKEN_NAMES; do echo -n "+1 ${POLICY_ID}.${i}"; done`
MINT_FLAGS=${MINT_OUTPUTS:1}

# 5. Calculate fees for the transaction
# 5.1 Build a draft transaction to calculate fees
#	          --invalid-before $TX_BEFORE \
#	          --invalid-hereafter $TX_AFTER \
cardano-cli transaction build-raw \
            --metadata-json-file ${META_JSON} \
            $ERA \
            --fee 0 \
            ${IN_UTXO} \
            --tx-out="${TO_ADDR}+${TO_ADDR_LV} lovelace${OTHER_COINS}${MINT_OUTPUTS}" \
            --tx-out="${PERGAMON_ADDR}+${PERGAMON_FEE_LV} lovelace" \
            --mint="${MINT_FLAGS}" \
            --mint-script-file ${POLICY_SCRIPT} \
            --out-file ${DZ}/txbody-draft

# 5.2 Calculate actual fees for transaction
MIN_FEE=$(cardano-cli transaction calculate-min-fee \
	              $NET \
                      --tx-body-file ${DZ}/txbody-draft \
                      --tx-in-count ${UTXO_COUNT} \
                      --tx-out-count 2 \
                      --witness-count 1 \
                      --byron-witness-count 0 \
                      --protocol-params-file ${DZ}/protparams.json | awk '{print $1}')

# 6. Build actual transaction including correct fees
#	          --invalid-before $TX_BEFORE \
#	          --invalid-hereafter $TX_AFTER \
cardano-cli transaction build-raw \
            --metadata-json-file ${META_JSON} \
            $ERA \
            --fee ${MIN_FEE} \
	          ${IN_UTXO} \
            --tx-out="${TO_ADDR}+$(( $TO_ADDR_LV - ${MIN_FEE} )) lovelace${OTHER_COINS}${MINT_OUTPUTS}" \
            --tx-out="${PERGAMON_ADDR}+${PERGAMON_FEE_LV} lovelace" \
            --mint="${MINT_FLAGS}" \
            --mint-script-file ${POLICY_SCRIPT} \
            --out-file ${DZ}/txbody-ok-fee

# 7. Sign the transaction
cardano-cli transaction sign \
            $NET \
            --signing-key-file ${PAYMENT_SKEY} \
            --tx-body-file  ${DZ}/txbody-ok-fee \
            --out-file      ${DZ}/tx.signed

# 8. Submit the transaction to the blockchain
SUBMIT=`cardano-cli transaction submit \
	    $NET \
	    --tx-file ${DZ}/tx.signed 2>&1 || echo "ERROR"`
	    
TXID=`cardano-cli transaction txid --tx-file ${DZ}/tx.signed 2>&1 || echo "ERROR"`

# 9. publish policy to pool.pm
curl \
	-X POST \
	-H "Content-Type: application/json" \
	-s \
	-D ${DZ}/pool.pm.headers \
	--data-binary "@${POLICY_SCRIPT}" \
       	"https://pool.pm/register/policy/${POLICY_ID}" > ${DZ}/pool.pm.out 2> ${DZ}/pool.pm.err || true


cat <<EOF
{
  "submit": "$(echo -n $SUBMIT | tr -d '\"')",
  "txid": "$TXID"
}
EOF
