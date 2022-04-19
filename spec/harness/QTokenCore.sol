// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import "../../contracts/options/QToken.sol";

contract QTokenCore is QToken {
    constructor(
        address _underlyingAsset,
        address _strikeAsset,
        address _priceRegistry,
        address _assetsRegistry,
        address _oracle,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    )
        public
        QToken(
            _underlyingAsset,
            _strikeAsset,
            _priceRegistry,
            _assetsRegistry,
            _oracle,
            _expiryTime,
            _isCall,
            _strikePrice
        )
    {}

    function _assetSymbolAndDecimals(address _asset, address _assetsRegistry)
        internal
        view
        override
        returns (string memory symbol, uint8 decimals)
    {}

    function _qTokenName(
        address _underlyingAsset,
        address _strikeAsset,
        address _assetsRegistry,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    ) internal view override returns (string memory tokenName) {}

    function _qTokenSymbol(
        address _underlyingAsset,
        address _strikeAsset,
        address _assetsRegistry,
        uint88 _expiryTime,
        bool _isCall,
        uint256 _strikePrice
    ) internal view override returns (string memory tokenSymbol) {}

    function _getOptionType(bool _isCall)
        internal
        pure
        override
        returns (string memory chr, string memory str)
    {}

    function _displayedStrikePrice(
        uint256 _strikePrice,
        uint8 _strikePriceDecimals
    ) internal pure override returns (string memory strikePrice) {}

    function _uintToChars(uint256 _number)
        internal
        pure
        override
        returns (string memory chars)
    {}

    function _slice(
        string memory _s,
        uint256 _start,
        uint256 _end
    ) internal pure override returns (string memory slice) {}

    function _getMonth(uint256 _month)
        internal
        pure
        override
        returns (string memory monthAbbrev, string memory monthName)
    {}
}
