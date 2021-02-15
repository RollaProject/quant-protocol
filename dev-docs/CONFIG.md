# Config

Right now lets keep config as it is.

TODO Revisit this file when it's clear what data will live in the config.

### Outstanding Design Questions:

- Do we want to be able to set multiple addresses for a single key? Feels like if we want to do that we can use the grantRole() method since it's probably some list of role members.
- Do we want to prevent values being set again once they're set? Probably not, but maybe we want to have timelocks... right now it's unclear what will live in config.
- How do we support the adding of new constants? or do we just want to have a function `getAddress(string constant)` which internally does the `keccak`?
