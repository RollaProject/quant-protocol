# Quant Protocol:

## Overview:

The Quant Protocol allows users to mint options, exercise options and reclaim any excess collateral from options they minted which have expired and settled.

The Quant protocol tokenises options using the ERC20 standard, and also tokenises a receipt of mint known as a "CollateralToken" which uses the ERC1155 standard. Minting an option requires more collateral than will be claimed by the exerciser. The Collateral Token entitles the option minter to reclaim any excess collateral once the option has expired.

### Options Collateral Requirements:

Options are fully collaterised meaning whatever the price of the underlying there will always be sufficient collateral to payout option buyers. 

#### Options:
- Calls are collaterised and settled in the underlying. For example, an ETH call requires 1 ETH (underlying asset). This is the max loss of the option i.e. the value at exercise can never exceed 1 ETH.
- Puts are collaterised and settled in USDC. For example, a $400 ETH PUT requires 400 USDC in collateral. Again, this is the max loss of the option.

#### Spreads:

### Settlement:

Options are European style which means they can only be exercised once they have expired.

The protocol uses oracles to get the settlement price once an option has expired. It must first be submitted to the system from the relevant oracle and the status of the option will become "SETTLED" allowing owners of options to exercise.

## Contracts:

### Options:

- QToken: An ERC20 Token representing an option. Instances of QTokens are created by the OptionsFactory
- CollateralToken: An ERC1155 Token representing a receipt of provided collateral. They are also used to represent spreads as a relevant QToken can be used to forgo some collateral when minting an option.
- OptionsFactory: Contract responsible for the management of QTokens and their associated collateral tokens.
- AssetsRegistry: Contract for managing details of underlying assets such as their decimals and minimum trade amount. Options can only be created for underlying assets in this registry.

### Pricing:

[Pricing Documentation](PRICING.md)

### Controller:

The entry point for most user actions. Allows users to mint options, mint spreads, exercise options and spreads, neutralize positions and reclaim collateral (after expiry).

[Controller Documentation](CONTROLLER.md)

### Periphery:

- OptionsRegistry: An options registry for managing a set of options. This is not used by the protocol and provided for user's such as 3rd parties who'd like to deploy and maintain a list of options on-chain.