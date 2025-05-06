#!/bin/bash

# ================================
# 🚀 WUSD Smart Contract Deployment Script 🚀
# ================================

# Configuration
APTOS_CLI="aptos"
PROFILE="default" # Aptos CLI profile name
MODULE_PATH="./sources" # Path to Move contract
DEPLOYER_ADDRESS="0x2b8dd3debf2dac56a82ba5ed2753d5afa1e9b9a5b4d7f5ecad25a2cb565f3cd9" # Deployer address
NETWORK="testnet" # Network type (testnet or mainnet)

# Helper function for colorful output
print_step() {
    echo -e "\033[1;34m[STEP]\033[0m $1"
}

print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Step 0: Install Aptos CLI if not installed
if ! command -v $APTOS_CLI &> /dev/null; then
    print_step "Aptos CLI is not installed. Installing via Homebrew..."
    brew update && brew install aptos
    if [ $? -ne 0 ]; then
        print_error "Failed to install Aptos CLI. Please check your Homebrew setup."
        exit 1
    fi
    print_success "Aptos CLI installed successfully!"
else
    print_success "Aptos CLI is already installed. Skipping installation step."
fi

# Step 1: Check if Aptos CLI is initialized
if [ ! -f ".aptos/config.yaml" ]; then
    print_step "Aptos CLI is not initialized. Starting interactive initialization..."
    $APTOS_CLI init --profile $PROFILE
    if [ $? -ne 0 ]; then
        print_error "Aptos CLI initialization failed. Please check your configuration."
        exit 1
    fi
    print_success "Aptos CLI initialized successfully!"
else
    print_success "Aptos CLI is already initialized. Skipping initialization step."
fi

# Step 2: Let the user choose the network
print_step "Please select the network:"
echo "1) Testnet"
echo "2) Mainnet"
read -p "Enter your choice (1 or 2): " NETWORK_CHOICE

if [ "$NETWORK_CHOICE" == "1" ]; then
    NETWORK="testnet"
elif [ "$NETWORK_CHOICE" == "2" ]; then
    NETWORK="mainnet"
else
    print_error "Invalid choice. Please run the script again and select 1 or 2."
    exit 1
fi
print_success "Selected network: $NETWORK"

# Step 3: Read DEPLOYER_ADDRESS from Aptos CLI configuration
print_step "Reading deployer address from Aptos CLI configuration..."
DEPLOYER_ADDRESS=$(grep -A 5 "profiles:" ".aptos/config.yaml" | grep "account:" | awk '{print "0x"$2}')
if [ -z "$DEPLOYER_ADDRESS" ]; then
    print_error "Failed to read deployer address from Aptos CLI configuration. Please ensure Aptos CLI is initialized."
    exit 1
fi
print_success "Deployer address: $DEPLOYER_ADDRESS"

# Step 4: Compile Move Contract
print_step "Compiling Move contract..."
$APTOS_CLI move compile --package-dir . --named-addresses stablecoin=$DEPLOYER_ADDRESS,master_minter=$DEPLOYER_ADDRESS,minter=$DEPLOYER_ADDRESS,pauser=$DEPLOYER_ADDRESS,denylister=$DEPLOYER_ADDRESS,recover=$DEPLOYER_ADDRESS,burner=$DEPLOYER_ADDRESS
if [ $? -ne 0 ]; then
    print_error "Compilation failed. Please check your code."
    exit 1
fi
print_success "Compilation completed successfully!"

# Step 5: Publish Move Contract
print_step "Publishing Move contract to the $NETWORK network..."
$APTOS_CLI move publish --package-dir . --profile $PROFILE --named-addresses stablecoin=$DEPLOYER_ADDRESS,master_minter=$DEPLOYER_ADDRESS,minter=$DEPLOYER_ADDRESS,pauser=$DEPLOYER_ADDRESS,denylister=$DEPLOYER_ADDRESS,recover=$DEPLOYER_ADDRESS,burner=$DEPLOYER_ADDRESS --assume-yes
if [ $? -ne 0 ]; then
    print_error "Publishing failed. Please check your configuration."
    exit 1
fi
print_success "Contract published successfully!"

# Final Message
EXPLORER_URL="https://explorer.aptoslabs.com/account/$DEPLOYER_ADDRESS?network=$NETWORK"
echo -e "\033[1;33m✨ Deployment and initialization completed! Your WUSD contract is live on the Aptos $NETWORK network. ✨\033[0m"
echo -e "\033[1;36m🔗 You can view the contract details here: $EXPLORER_URL\033[0m"