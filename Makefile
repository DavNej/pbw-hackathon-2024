-include .env

.PHONY: help all clean remove install update build anvil show-config deploy

help:
	@echo "Usage:"
	@echo '  make deploy ARGS="--network sepolia"'
	@echo '  make token-balance-of-europool'
	@echo ""
	@echo "  Supported networks: sepolia, mumbai, alfajores. Default network is anvil."

all: clean remove install update build
clean :; forge clean
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"
# install :; forge install foundry-rs/forge-std@v1.7.6 --no-commit && forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit
install :; forge install foundry-rs/forge-std@v1.7.6 --no-commit && forge install OpenZeppelin/openzeppelin-contracts@v4.9.6 --no-commit
update:; forge update
build:
	@echo "Building contracts..."
	@forge build

## Launch local chain
anvil:
	@anvil --chain-id 1337 -m 'test test test test test test test test test test test junk'


## Deploy rules
NETWORK_NAME := ""
NETWORK_ARGS := ""
RPC_URL := ""
DEPLOYER_ADDRESS := $(TESNET_DEPLOYER_ADDRESS)
KEYSTORE_ARGS := "--account devDeployer --password-file .passwords/devDeployer.txt --sender $(DEPLOYER_ADDRESS)"
VERIFY_ARGS := ""

ifeq ($(findstring --network alfajores,$(ARGS)),--network alfajores)
	NETWORK_NAME := Alfajores
	NETWORK_ARGS := --rpc-url $(ALFAJORES_RPC_URL)
	RPC_URL := $(ALFAJORES_RPC_URL)
	VERIFY_ARGS := "--verify --etherscan-api-key $(CELOSCAN_API_KEY)"
endif

ifeq ($(findstring --network mumbai,$(ARGS)),--network mumbai)
	NETWORK_NAME := "Mumbai"
	NETWORK_ARGS := --rpc-url $(MUMBAI_RPC_URL)
	RPC_URL := $(MUMBAI_RPC_URL)
	VERIFY_ARGS := "--verify --etherscan-api-key $(POLYGONSCAN_API_KEY)"
endif

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_NAME := "Sepolia"
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL)
	RPC_URL := $(SEPOLIA_RPC_URL)
	VERIFY_ARGS := "--verify --etherscan-api-key $(ETHERSCAN_API_KEY)"
endif

ifeq ($(strip $(ARGS)),)
	NETWORK_NAME := "Anvil"
	NETWORK_ARGS := "--rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_DEPLOYER_PRIVATE_KEY)"
	KEYSTORE_ARGS := ""
	DEPLOYER_ADDRESS := $(ANVIL_DEPLOYER_ADDRESS)
endif


show-config:
	@echo "NETWORK_NAME:\t\t$(NETWORK_NAME)"
	@echo "NETWORK_ARGS:\t\t$(NETWORK_ARGS)"
	@echo "RPC_URL:\t\t$(RPC_URL)"
	@echo "DEPLOYER_ADDRESS:\t$(DEPLOYER_ADDRESS)"
	@echo "KEYSTORE_ARGS:\t\t$(KEYSTORE_ARGS)"
	@echo "VERIFY_ARGS:\t\t$(VERIFY_ARGS)"

deploy-command:
	@echo "Generate deploy command for $(NETWORK_NAME)..."
	@echo "forge script script/Deploy.s.sol $(NETWORK_ARGS) $(KEYSTORE_ARGS) --broadcast $(VERIFY_ARGS) -vvvv"
