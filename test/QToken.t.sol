// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {ERC20 as SolmateERC20} from "solmate/src/tokens/ERC20.sol";
import {SimpleOptionsFactory} from "../src/mocks/SimpleOptionsFactory.sol";
import {AssetsRegistry} from "../src/options/AssetsRegistry.sol";

contract ERC20 is SolmateERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) SolmateERC20(_name, _symbol, _decimals) {}
}

contract QTokenTest is Test {
    ERC20 WETH;
    ERC20 BUSD;
    ERC20 DOGE;
    AssetsRegistry assetsRegistry;

    function setUp() public {
        WETH = new ERC20("Wrapped Ether", "WETH", 18);
        BUSD = new ERC20("BUSD Token", "BUSD", 18);
        DOGE = new ERC20("DOGE Coin", "DOGE", 8);

        assetsRegistry = new AssetsRegistry();
        assetsRegistry.addAssetWithOptionalERC20Methods(address(WETH));
        assetsRegistry.addAssetWithOptionalERC20Methods(address(BUSD));
        assetsRegistry.addAssetWithOptionalERC20Methods(address(DOGE));
    }
}
