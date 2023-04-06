#!/usr/bin/bash
################################
#                              #
#  CARDANO SPO SETUP COMMANDS  #
#                              #
################################

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

# Step 1f - Generate Cold keys (in production would create on isolated machine not connected to internet
#                                and would manually copy public keys only across on USB stick)
cardano-cli node key-gen \
    --cold-verification-key-file cold.vkey \
    --cold-signing-key-file cold.skey \
    --operational-certificate-issue-counter-file opcert.counter

# Step 1g - Generate KES (Key Evolving Signature) keys
cardano-cli node key-gen-KES \
    --verification-key-file kes.vkey \
    --signing-key-file kes.skey

# Step 1h - Generate VRF (Verifiable Random Function) keys
cardano-cli node key-gen-VRF \
   --verification-key-file vrf.vkey \
   --signing-key-file vrf.skey

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

