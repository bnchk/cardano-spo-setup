#!/usr/bin/bash
################################################
#                                              #
#    CARDANO SPO SETUP - PARTIALLY AUTOMATED   #
#    CARDANO SPO SETUP - PARTIALLY AUTOMATED   #  GAVE UP AS FAUCET APPEARS TO REQUIRE API KEY FOR FUNDS IN AUTO FORMAT
#    CARDANO SPO SETUP - PARTIALLY AUTOMATED   #
#                                              #
################################################

#TODO => Would need to make rundir above current directory because the repo loads all the files created otherwise!!!

#######################
# INITIALISATION
#######################
export HOME_DIR="/config/workspace"              # define home directory for storage above this repo directory
#export DIR_ARCHIVE="$HOME_DIR/archived"   # define archive directory below this
export YYMD_HM=`date +"%Y%m%d_%H%M"`      # put program start timestamp in variable
export RUN_NUM=`ls -l $HOME_DIR | grep ^d | awk '{print $9}' | grep ^run | cut -c4-5 | sort | tail -1 | sed 's/^0*//g' | { read -r -t1 val && echo $val || echo 0 ; } | awk '{ print $1+1}' | awk '{ print "0" $1}' | rev | cut -c1-2 | rev`
echo "RUN: $RUN_NUM"
export RUN_DIR="${HOME_DIR}/run${RUN_NUM}_${YYMD_HM}"   # define archive directory below this
[ ! -d $RUN_DIR ] && mkdir $RUN_DIR && echo -e "Created: Run Directory - $RUN_DIR"  # create archive directory if it isn't there

# DEFINE FILES
export PAYMENT_VKEY=$RUN_DIR/payment.vkey
export PAYMENT_SKEY=$RUN_DIR/payment.skey
export STAKE_VKEY=$RUN_DIR/stake.vkey
export STAKE_SKEY=$RUN_DIR/stake.skey
export PAYMENT_WITH_STAKE_ADDR=$RUN_DIR/payment_wth_stake.addr
export STAKE_ADDR=$RUN_DIR/stake.addr
export STAKE_CERT=$RUN_DIR/stake.cert
export TX_RAW=$RUN_DIR/tx.raw
export TX_SIGNED=$RUN_DIR/tx.signed

#export FAUCET_FQDN="https://docs.cardano.org/cardano-testnet/tools/faucet"
export FAUCET_FQDN="https://faucet.preview.world.dev.cardano.org/"
export FAUCET_LOG=$RUN_DIR/faucet.log


#######################
# CLEANUP PREVIOUS RUNS
#######################
#[ ! -d $DIR_ARCHIVE ] && mkdir $DIR_ARCHIVE && echo -e "Created: Archive Directory - $DIR_ARCHIVE\n"  # create archive directory if it isn't there
#[ `ls -l $HOME_DIR/*.gz | wc -l | awk '{ print $1 }'` -gt 0 ] && mv $HOME_DIR/*.gz $HOME_DIR/*.gz && \
#   echo -e "WARNING: Moved previous runs zip to archive - did last run crash\n"                         # create archive directory if it isn't there


###################################################################################################
# STEP 1 - CREATE REQUIRED KEY PAIRS AND ADDRESSES
#        - There are 2 key pairs to create, payment and stake 
#        - These are then used to generate matching addresses
#           https://developers.cardano.org/docs/stake-pool-course/handbook/create-stake-pool-keys/

# STEP 1a - Payment Key creation - same as for a wallet - payment key and secret signing key
cardano-cli address key-gen \
    --verification-key-file $PAYMENT_VKEY \
    --signing-key-file      $PAYMENT_SKEY
[ $? -ne 0 ] && { echo -e "\nERROR EXIT - Payment key pair creation\n"; exit; } || { echo "Created: Payment key pair"; }

# Step 1b - Stake key pair generation
cardano-cli stake-address key-gen \
    --verification-key-file $STAKE_VKEY \
    --signing-key-file      $STAKE_SKEY
[ $? -ne 0 ] && { echo -e "\nERROR EXIT - Stake key pair creation\n"; exit; } || { echo "Created: Stake key pair"; }

# Step 1c - Payment address generation (uses both the payment and stake public verification keys)
cardano-cli address build \
    --payment-verification-key-file $PAYMENT_VKEY \
    --stake-verification-key-file   $STAKE_VKEY \
    --out-file                      $PAYMENT_WITH_STAKE_ADDR \
    --testnet-magic                 $CARDANO_NODE_MAGIC
[ $? -ne 0 ] && { echo -e "\nERROR EXIT - Payment address creation\n"; exit; } || { echo "Created: Payment address"; }

# Step 1d - Stake address generation (only for where protocol rewards are sent automatically)
cardano-cli stake-address build \
    --stake-verification-key-file $STAKE_VKEY \
    --out-file                    $STAKE_ADDR \
    --testnet-magic               $CARDANO_NODE_MAGIC
[ $? -ne 0 ] && { echo -e "\nERROR EXIT - Stake protocol address creation\n"; exit; } || { echo "Created: Stake protocol address"; }
exit
# Step 1e - Use faucet to load funds into the payment address
##curl -v -XPOST "$FAUCET_FQDN/send-money/$PAYMENT_WITH_STAKE_ADDR"
curl -v -XPOST "$FAUCET_FQDN/send-money/$(cat $PAYMENT_WITH_STAKE_ADDR)?api_key=nohnuXahthoghaeNoht9Aow3ze4quohc" >$FAUCET_LOG 2>&1
cat $FAUCET_LOG
exit

###################################################################################################
# STEP 2 - REGISTER STAKE CERTIFICATE WITH THE BLOCKCHAIN
#        - Create the Registration Certificate for the stake pool
#        - Create the transaction to submit the certificate to the blockchain
#        - Sign the transaction
#        - Submit the transaction

# Step 2a - Registration Certificate creation
cardano-cli stake-address registration-certificate \
    --stake-verification-key-file $STAKE_VKEY \
    --out-file s                  $STAKE_CERT

# Step 2b - Create Transaction (to be used to submit the certificate)
#         - requires -> finding the UTXO (hash and tx_id) to be used for the payment
#         - requires -> finding the slot number the blockchain tip is currently at

# find the UTXO hash and txid
cardano-cli query utxo \
    --address       $(cat $PAYMENT_WITH_STAKE_ADDR) \
    --testnet-magic $CARDANO_NODE_MAGIC
#TODO #1 => needs the TxHash for largest ADA amount, plus TxId into variables

# find the slotnumber that the tip of blockchain is up to
cardano-cli query tip --mainnet
#TODO #2 => needs the slot into a variable

# build the transaction (noting an additional step can be done to calculate the change exactly)
cardano-cli transaction build \
    --alonzo-era \
    --tx-in b64ae44e1195b04663ab863b62337e626c65b0c9855a9fbb9ef4458f81a6f5ee#1 \
    --tx-out $(cat payment.addr)+1000000 \
    --change-address $(cat payment.addr) \
    --testnet-magic $CARDANO_NODE_MAGIC  \
    --out-file tx.raw \
    --certificate-file stake.cert \
    --invalid-hereafter 987654 \
    --witness-override 2
#TODO #3 => integrate the variables from above

# Step 2c - sign the transaction
cardano-cli transaction sign \
    --tx-body-file tx.raw \
    --signing-key-file payment.skey \
    --signing-key-file stake.skey \
    --testnet-magic $CARDANO_NODE_MAGIC \
    --out-file tx.signed

# Step 2d - submit the transaction
cardano-cli transaction submit \
    --tx-file tx.signed \
    --testnet-magic $CARDANO_NODE_MAGIC



#TODO #4 => next up is maybe kes keys?  They get a bit sketchy here between videos and text guide

# kes keys?
# topology files?
# 

