// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.16;

import "solady/src/auth/OwnableRoles.sol";
import "../interfaces/IPriceRegistry.sol";
import "../interfaces/IOracleRegistry.sol";
import "../libraries/QuantMath.sol";

/// @title For centrally managing a log of settlement prices, for each option.
/// @author Rolla
contract PriceRegistry is OwnableRoles, IPriceRegistry {
    using QuantMath for uint256;
    using QuantMath for QuantMath.FixedPointInt;

    uint32 private _disputePeriod;

    uint8 private immutable _strikeAssetDecimals;

    uint256 private immutable _disputerRole = _ROLE_0;

    /// @inheritdoc IPriceRegistry
    address public immutable oracleRegistry;

    /// @dev oracle => asset => expiry => price
    mapping(address => mapping(address => mapping(uint88 => PriceWithDecimals))) private _settlementPrices;

    /// @param strikeAssetDecimals_ address of quant central configuration
    constructor(uint8 strikeAssetDecimals_, uint32 diputePeriod_, address oracleRegistry_) {
        require(oracleRegistry_ != address(0), "PriceRegistry: invalid oracle registry address");

        _strikeAssetDecimals = strikeAssetDecimals_;
        _disputePeriod = diputePeriod_;
        oracleRegistry = oracleRegistry_;
        _initializeOwner(msg.sender);
    }

    /// @inheritdoc IPriceRegistry
    function setSettlementPrice(
        address _asset,
        uint88 _expiryTime,
        uint8 _settlementPriceDecimals,
        uint256 _settlementPrice
    ) external override {
        address oracle = msg.sender;

        require(
            IOracleRegistry(oracleRegistry).isOracleRegistered(oracle)
                && IOracleRegistry(oracleRegistry).isOracleActive(oracle),
            "PriceRegistry: Price submitter is not an active oracle"
        );

        uint256 currentSettlementPrice = _settlementPrices[oracle][_asset][_expiryTime].price;

        require(currentSettlementPrice == 0, "PriceRegistry: Settlement price has already been set");

        require(_expiryTime <= block.timestamp, "PriceRegistry: Can't set a price for a time in the future");

        _settlementPrices[oracle][_asset][_expiryTime] = PriceWithDecimals(_settlementPrice, _settlementPriceDecimals);

        emit PriceStored(oracle, _asset, _expiryTime, _settlementPriceDecimals, _settlementPrice);
    }

    /// @inheritdoc IPriceRegistry
    function disputeSettlementPrice(
        address _oracle,
        address _asset,
        uint88 _expiryTime,
        uint8 _settlementPriceDecimals,
        uint256 _settlementPrice
    ) external override {
        require(hasAnyRole(msg.sender, _disputerRole), "PriceRegistry: Caller is not a disputer");
        require(
            _settlementPrices[_oracle][_asset][_expiryTime].price != 0,
            "PriceRegistry: Settlement price has not been set"
        );
        require(block.timestamp <= _expiryTime + _disputePeriod, "PriceRegistry: Dispute period has ended");

        _settlementPrices[_oracle][_asset][_expiryTime] = PriceWithDecimals(_settlementPrice, _settlementPriceDecimals);

        emit PriceStored(_oracle, _asset, _expiryTime, _settlementPriceDecimals, _settlementPrice);
    }

    /// @inheritdoc IPriceRegistry
    function setDisputePeriod(uint32 disputePeriod_) external override onlyOwner {
        _disputePeriod = disputePeriod_;

        emit DisputePeriodSet(disputePeriod_);
    }

    /// @inheritdoc IPriceRegistry
    function getSettlementPriceWithDecimals(address _oracle, uint88 _expiryTime, address _asset)
        external
        view
        override
        returns (PriceWithDecimals memory settlementPrice)
    {
        settlementPrice = _settlementPrices[_oracle][_asset][_expiryTime];
        require(settlementPrice.price != 0, "PriceRegistry: No settlement price has been set");
    }

    /// @inheritdoc IPriceRegistry
    function getSettlementPrice(address _oracle, uint88 _expiryTime, address _asset)
        external
        view
        override
        returns (uint256)
    {
        PriceWithDecimals memory settlementPrice = _settlementPrices[_oracle][_asset][_expiryTime];
        require(settlementPrice.price != 0, "PriceRegistry: No settlement price has been set");

        //convert price to the correct number of decimals
        return settlementPrice.price.fromScaledUint(settlementPrice.decimals).toScaledUint(_strikeAssetDecimals, true);
    }

    function getOptionPriceStatus(address _oracle, uint88 _expiryTime, address _asset)
        external
        view
        override
        returns (PriceStatus)
    {
        if (block.timestamp >= _expiryTime) {
            if (hasSettlementPrice(_oracle, _expiryTime, _asset)) {
                return PriceStatus.SETTLED;
            }
            return PriceStatus.AWAITING_SETTLEMENT_PRICE;
        } else {
            return PriceStatus.ACTIVE;
        }
    }

    /// @inheritdoc IPriceRegistry
    function hasSettlementPrice(address _oracle, uint88 _expiryTime, address _asset)
        public
        view
        override
        returns (bool)
    {
        return _settlementPrices[_oracle][_asset][_expiryTime].price != 0;
    }
}
