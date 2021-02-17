// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

pragma experimental ABIEncoderV2;

//todo: do we want this contract to be upgradeable?
///@dev this contract will manage ownership of all the funds in the protocol
contract Controller is Initializable, OwnableUpgradeSafe, ReentrancyGuardUpgradeSafe {
    using SafeMath for uint256;

    ///@notice get a qToken's payout/cash value after expiry, in the collateral asset
    ///@return collateral returned and amount
    function getPayout(address _qtoken, uint256 _amount) public view returns (uint256) {
        //check option has expired. fail if not.
        //calculate the payout in qToken collateralAsset (getCollateralAsset())
        return 1;
    }

    //NOTE: This will also need to be callable by the exchange contract at some point (so it can mint and sell)
    ///@notice mints both the long and short token to the users account if they have collateral required
    function mintOption(address qToken) public {
        //1. get the collateral requirement to mint amountOfOptions

        //2. pull collateral from user account (we should do this using a central proxy as middle man)

        //3. mint both the short and long option. send to the user. the user then has both sides and can do what they want with these
    }

    //this function should let you pass in an option token, an amount and assuming you have enough short tokens
    //matching amountOfOptions, then it should close out your position
    //public because the exchange will probably do this automatically after a trade
    //(if a user was short and bought long it can then neutralise for the end user)
    function neutralisePosition(address qToken, uint256 amountOfOptions) public {
        //check they have the right amount of long token
        //check they have right amount of short token (this is the token that is collaterizedFrom 0 i.e. not a spread)
        //burn both tokens and return the collateral the user is entitled to
    }

    //allow user to exercise their option (long token)
    function exercise(address qToken) internal {
        //getPayout to find out how much is claimable (will fail if the option hasnt expired)
    }

    //allow user to exchange their collateral token for any coll
    function claimRemainingCollateral(bytes32 collateralCoupon) internal {
        //check option has expired
        //check user has enough of that collateral coupon and get balance
        //get amount of collateral that is not needed to give to exerciser (note: also support spreads)
        //give back collateral to seller
    }

    //TODO: Removed vault stuff so we will need functions to create spreads. deposit / withdrawal collateral from collateral coupon

    //TODO: Bonus features: (lets not worry about for now, but leave todo's so we don't forget)
    //TODO: Our proxy should allow the user to approve a 3rd party to spend their assets on their behalf like operator
    //TODO: See if we can add action batching as well. less important as gas is cheap on matic
}
