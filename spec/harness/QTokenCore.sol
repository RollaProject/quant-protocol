// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma abicoder v2;

import "../../contracts/options/QToken.sol";

contract QTokenCore is QToken {
    constructor(
        address _quantConfig,
        address _underlyingAsset,
        address _strikeAsset,
        address _oracle,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    )
        public
        QToken(
            _quantConfig,
            _underlyingAsset,
            _strikeAsset,
            _oracle,
            _strikePrice,
            _expiryTime,
            _isCall
        )
    {}

    function _assetSymbol(address _quantConfig, address _asset)
        internal
        view
        override
        returns (string memory symbol)
    {}

    function _qTokenName(
        address _quantConfig,
        address _underlyingAsset,
        address _strikeAsset,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) internal view override returns (string memory tokenName) {}

    function _qTokenSymbol(
        address _quantConfig,
        address _underlyingAsset,
        address _strikeAsset,
        uint256 _strikePrice,
        uint256 _expiryTime,
        bool _isCall
    ) internal view override returns (string memory tokenSymbol) {}

    function _getOptionType(bool _isCall)
        internal
        pure
        override
        returns (string memory chr, string memory str)
    {}

    function _displayedStrikePrice(uint256 _strikePrice)
        internal
        pure
        override
        returns (string memory strikePrice)
    {}

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
