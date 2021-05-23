# Pricing Mechanism

## General Details

The Quant Pricing system is composed of a few different contracts which are outlined below.

#### Price Registry

Price Registry keeps a log of all settlement prices for options in the system. This ensures that we have a central log for pricing which can be used for exercising regardless of what happens to a provider's data store in future.

#### Oracle Manager

In order to fetch a price for the underlying asset, we need to use an oracle. An Oracle manager is needed per provider of price feeds. The system is designed to cater for any oracle provider by providing a generic interface `ProviderOracleManager`. This abstract contract offers the functionality for Quant to manage oracles - add, view but NOT remove. This is by design to ensure that once an oracle has been set, it can't be changed - as it may have already been used in an option. This means anyone buying an option with an oracle attached, can ensure that the oracle price feed at the time of buying will match the feed at the time of exercising since it can't be changed once set.

`ProviderOracleManager` can be extended by any oracle provider. Currently, Chainlink is supported only.

#### Oracle Registry

An oracle registry is needed to maintain a list of official oracle providers in the Quant system. We mandate that any option created must use an oracle from the oracle registry. This ensures that if someone attempted to create their own malicious oracle which misreports prices, and attempted to create options linked to that oracle, it would fail as the oracle is not in the whitelist.

## Provider Details

#### Chainlink Oracle Price Submission

The way chainlink oracles work is based on roundId's. Each time a new price is submitted on a feed a new roundId is used to identify the round. This roundId increments for each subsequent round but is not guaranteed to increment by 1. We do a binary search to find the last timestamp pre-expiry and use this as the settlement price.
