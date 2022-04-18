// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import "ds-test/test.sol";

contract AssetsRegistry {}

contract OptionsFactory {
    AssetsRegistry public assetsRegistry;

    constructor(address _assetsRegistry) {
        assetsRegistry = AssetsRegistry(_assetsRegistry);
    }
}

contract QuantCalculator {
    address public assetsRegistry;
    address public optionsFactory;

    constructor(address _assetsRegistry, address _optionsFactory) {
        assetsRegistry = _assetsRegistry;
        optionsFactory = _optionsFactory;
    }
}

contract StorageBenchTest is DSTest {
    QuantCalculator public quantCalculator;

    function setUp() public {
        AssetsRegistry assetsRegistry = new AssetsRegistry();
        OptionsFactory optionsFactory = new OptionsFactory(
            address(assetsRegistry)
        );
        quantCalculator = new QuantCalculator(
            address(assetsRegistry),
            address(optionsFactory)
        );
    }

    function testReadFromFactory() public {
        emit log_address(
            address(
                OptionsFactory(quantCalculator.optionsFactory())
                    .assetsRegistry()
            )
        );
    }

    function testReadFromDirectStorageRef() public {
        emit log_address(quantCalculator.optionsFactory());
    }
}
