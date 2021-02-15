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

The way chainlink oracles work is based on roundId's. Each time a new price is submitted on a feed a new roundId is used to identify the round. This roundId increments for each subsequent round but is not guaranteed to increment by 1.

# TODO:

- Allow anyone to submit a price which is open to being challenged for a set period of time by someone else submitting a price from a more recent roundId and a timestamp less than expiry. By doing this we only need 1 honest party to successfully submit the price in the submission window, and ANYONE can do it without any authority. We can also have a `finaliseEarly()` method which can be called which iterates rounds by 1 to find the next roundId and if the next one has a higher timestamp we can be sure that the right one is submitted - this will only work if the roundId can be found before we run out of gas.
  We need to think how price submission will work for options outside of Quant Web. Do we want to submit prices for options random people are creating?