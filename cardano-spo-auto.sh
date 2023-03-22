#!/usr/bin/bash
################################################
#                                              #
#    CARDANO SPO SETUP - PARTIALLY AUTOMATED   #
#    CARDANO SPO SETUP - PARTIALLY AUTOMATED   #
#    CARDANO SPO SETUP - PARTIALLY AUTOMATED   #
#                                              #
################################################


#######################
# INITIALISATION
#######################
export DIR_HOME=`pwd`                     # define home directory as current script calling directory
export DIR_ARCHIVE="$DIR_HOME/archived"   # define archive directory below this

#######################
# CLEANUP PREVIOUS RUNS
#######################
[ ! -d $DIR_ARCHIVE ] && mkdir $DIR_ARCHIVE



###################################################################################################
# STEP 1 - CREATE REQUIRED KEY PAIRS AND ADDRESSES
#        - There are 2 key pairs to create, payment and stake 
#        - These are then used to generate matching addresses
#           https://developers.cardano.org/docs/stake-pool-course/handbook/create-stake-pool-keys/

# STEP 1a - Payment Key creation - same as for a wallet - payment key and secret signing key
cardano-cli address key-gen \
    --verification-key-file payment.vkey \
    --signing-key-file payment.skey


# Step 1b - Stake key pair generation
cardano-cli stake-address key-gen \
    --verification-key-file stake.vkey \
    --signing-key-file stake.skey

# Step 1c - Payment address generation (uses both the payment and stake public verification keys)
cardano-cli address build \
    --payment-verification-key-file payment.vkey \
    --stake-verification-key-file stake.vkey \
    --out-file payment.addr \
    --testnet-magic $CARDANO_NODE_MAGIC

# Step 1d - Stake address generation (only for where protocol rewards are sent automatically)
cardano-cli stake-address build \
    --stake-verification-key-file stake.vkey \
    --out-file stake.addr \
    --testnet-magic $CARDANO_NODE_MAGIC

# Step 1e - Use faucet to load funds into the payment address (cat payment.addr)
curl -XPOST "http[s]://$FQDN:$PORT/send-money/$(cat payment.addr)"


###################################################################################################
# STEP 2 - REGISTER STAKE CERTIFICATE WITH THE BLOCKCHAIN
#        - Create the Registration Certificate for the stake pool
#        - Create the transaction to submit the certificate to the blockchain
#        - Sign the transaction
#        - Submit the transaction

# Step 2a - Registration Certificate creation
cardano-cli stake-address registration-certificate \
    --stake-verification-key-file stake.vkey \
    --out-file stake.cert

# Step 2b - Create Transaction (to be used to submit the certificate)
#         - requires -> finding the UTXO (hash and tx_id) to be used for the payment
#         - requires -> finding the slot number the blockchain tip is currently at

# find the UTXO hash and txid
cardano-cli query utxo \
    --address $(cat payment.addr) \
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

