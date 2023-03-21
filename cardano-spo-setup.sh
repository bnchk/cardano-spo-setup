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
curl -XPOST "http[s]://$FQDN:$PORT/send-money/$ADDRESS"


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
