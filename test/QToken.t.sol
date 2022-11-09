// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {ERC20 as SolmateERC20} from "solmate/src/tokens/ERC20.sol";
import {SimpleOptionsFactory} from "../src/mocks/SimpleOptionsFactory.sol";
import {AssetsRegistry} from "../src/options/AssetsRegistry.sol";
import {QToken} from "../src/options/QToken.sol";
import {OptionsUtils} from "../src/libraries/OptionsUtils.sol";

contract ERC20 is SolmateERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals) SolmateERC20(_name, _symbol, _decimals) {}
}

contract QTokenTest is Test {
    ERC20 WETH;
    ERC20 BUSD;
    ERC20 DOGE;
    AssetsRegistry assetsRegistry;
    SimpleOptionsFactory optionsFactory;
    address defaultOracle = address(1337);
    uint256 defaultStrikePrice = 1400 ether; // 18 decimals
    uint88 defaultExpiryTime = 1618592400; // April 16th, 2021
    bool defaultIsCall = false;
    QToken defaultQToken;

    bytes32 constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    uint256 constant SECP256K1_PRIV_KEY_LIMIT =
        115792089237316195423570985008687907852837564279074904382605163141518161494336;

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    struct PermitTestArgs {
        string name;
        string symbol;
        uint8 decimals;
        address oracle;
        uint32 expiryTime;
        bool isCall;
        uint256 strikePrice;
        uint256 ownerPrivKey;
        address spender;
        uint256 value;
        uint256 deadline;
        uint256 otherPrivKey;
    }

    function setUp() public {
        WETH = new ERC20("Wrapped Ether", "WETH", 18);
        BUSD = new ERC20("BUSD Token", "BUSD", 18);
        DOGE = new ERC20("DOGE Coin", "DOGE", 8);

        assetsRegistry = new AssetsRegistry();
        assetsRegistry.addAssetWithOptionalERC20Methods(address(WETH));
        assetsRegistry.addAssetWithOptionalERC20Methods(address(BUSD));
        assetsRegistry.addAssetWithOptionalERC20Methods(address(DOGE));

        optionsFactory = new SimpleOptionsFactory(address(assetsRegistry), address(BUSD), address(this));

        (address qTokenAddress,) = optionsFactory.createOption(
            address(WETH), defaultOracle, defaultExpiryTime, defaultIsCall, defaultStrikePrice
        );
        defaultQToken = QToken(qTokenAddress);
    }

    function testCreateNewOption() public {
        assertEq(defaultQToken.symbol(), "ROLLA-WETH-16APR2021-1400-P");
        assertEq(defaultQToken.name(), "ROLLA WETH 16-April-2021 1400 Put");
        assertEq(defaultQToken.underlyingAsset(), address(WETH));
        assertEq(defaultQToken.strikeAsset(), address(BUSD));
        assertEq(defaultQToken.oracle(), defaultOracle);
        assertEq(defaultQToken.strikePrice(), defaultStrikePrice);
        assertEq(defaultQToken.expiryTime(), defaultExpiryTime);
        assertEq(defaultQToken.isCall(), defaultIsCall);
        assertEq(defaultQToken.decimals(), 18);
    }

    function testCreateNewOption(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address oracle,
        uint32 expiryTime,
        bool isCall,
        uint256 strikePrice
    ) public {
        uint256 nameLength = bytes(name).length;
        uint256 symbolLength = bytes(symbol).length;
        vm.assume(nameLength > 0 && nameLength <= 15);
        vm.assume(symbolLength > 0 && symbolLength <= 15);
        vm.assume(oracle != address(0));
        strikePrice = bound(strikePrice, 1, type(uint256).max);
        expiryTime = uint32(bound(expiryTime, block.timestamp, type(uint88).max));

        ERC20 underlying = new ERC20(name, symbol, decimals);
        assetsRegistry.addAssetWithOptionalERC20Methods(address(underlying));

        (address qTokenAddress,) =
            optionsFactory.createOption(address(underlying), oracle, expiryTime, isCall, strikePrice);
        QToken qToken = QToken(qTokenAddress);

        assertEq(qToken.underlyingAsset(), address(underlying));
        assertEq(qToken.strikeAsset(), address(BUSD));
        assertEq(qToken.oracle(), oracle);
        assertEq(qToken.strikePrice(), strikePrice);
        assertEq(qToken.expiryTime(), expiryTime);
        assertEq(qToken.isCall(), isCall);
        assertEq(qToken.decimals(), 18);
    }

    function testMint() public {
        uint256 amount = 5 ether; // 5 options
        address receiver = address(1234);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), receiver, amount);

        defaultQToken.mint(receiver, amount);

        assertEq(defaultQToken.balanceOf(receiver), amount);
        assertEq(defaultQToken.totalSupply(), amount);
    }

    function testMint(uint256 amount, address receiver) public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), receiver, amount);

        defaultQToken.mint(receiver, amount);

        assertEq(defaultQToken.balanceOf(receiver), amount);
        assertEq(defaultQToken.totalSupply(), amount);
    }

    function testBurn() public {
        uint256 mintAmount = 7 ether; // 7 options
        uint256 burnAmount = 3 ether; // 3 options
        address receiver = address(4567);

        defaultQToken.mint(receiver, mintAmount);

        vm.expectEmit(true, true, false, true);
        emit Transfer(receiver, address(0), burnAmount);

        defaultQToken.burn(receiver, burnAmount);

        assertEq(defaultQToken.balanceOf(receiver), mintAmount - burnAmount);
        assertEq(defaultQToken.totalSupply(), mintAmount - burnAmount);
    }

    function testBurn(uint256 mintAmount, uint256 burnAmount, address receiver) public {
        vm.assume(burnAmount <= mintAmount);

        defaultQToken.mint(receiver, mintAmount);

        vm.expectEmit(true, true, false, true);
        emit Transfer(receiver, address(0), burnAmount);

        defaultQToken.burn(receiver, burnAmount);

        assertEq(defaultQToken.balanceOf(receiver), mintAmount - burnAmount);
        assertEq(defaultQToken.totalSupply(), mintAmount - burnAmount);
    }

    function testCannotBurnMoreThanBalance() public {
        uint256 mintAmount = 7 ether; // 7 options
        uint256 burnAmount = 8 ether; // 8 options
        address receiver = address(4567);

        defaultQToken.mint(receiver, mintAmount);

        vm.expectRevert(stdError.arithmeticError);
        defaultQToken.burn(receiver, burnAmount);
    }

    function testCannotBurnMoreThanBalance(uint256 mintAmount, uint256 burnAmount, address receiver) public {
        vm.assume(burnAmount > mintAmount);

        defaultQToken.mint(receiver, mintAmount);

        vm.expectRevert(stdError.arithmeticError);
        defaultQToken.burn(receiver, burnAmount);
    }

    function testCannotMintWithUnauthorizedSender() public {
        uint256 amount = 5 ether; // 5 options
        address receiver = address(1234);
        address unauthorizedSender = address(5678);

        vm.assume(unauthorizedSender != address(this));
        vm.prank(unauthorizedSender);
        vm.expectRevert("QToken: caller != controller");
        defaultQToken.mint(receiver, amount);
    }

    function testCannotMintWithUnauthorizedSender(uint256 amount, address receiver, address unauthorizedSender)
        public
    {
        vm.assume(unauthorizedSender != address(this));
        vm.prank(unauthorizedSender);
        vm.expectRevert("QToken: caller != controller");
        defaultQToken.mint(receiver, amount);
    }

    function testCannotBurnWithUnauthorizedSender() public {
        uint256 mintAmount = 7 ether; // 7 options
        uint256 burnAmount = 3 ether; // 3 options
        address receiver = address(4567);
        address unauthorizedSender = address(5678);

        defaultQToken.mint(receiver, mintAmount);

        vm.assume(unauthorizedSender != address(this));
        vm.prank(unauthorizedSender);
        vm.expectRevert("QToken: caller != controller");
        defaultQToken.burn(receiver, burnAmount);
    }

    function testCannotBurnWithUnauthorizedSender(
        uint256 mintAmount,
        uint256 burnAmount,
        address receiver,
        address unauthorizedSender
    ) public {
        defaultQToken.mint(receiver, mintAmount);

        vm.assume(unauthorizedSender != address(this));
        vm.prank(unauthorizedSender);
        vm.expectRevert("QToken: caller != controller");
        defaultQToken.burn(receiver, burnAmount);
    }

    function testCreateOptionWithDecimalsInStrikePrice() public {
        uint256 strikePrice = 1912340000000000000000;
        uint88 expiryTime = 1630768904;

        (address qTokenAddress,) =
            optionsFactory.createOption(address(WETH), defaultOracle, expiryTime, true, strikePrice);

        QToken qToken = QToken(qTokenAddress);

        assertEq(qToken.strikePrice(), strikePrice);
        assertEq(qToken.symbol(), "ROLLA-WETH-04SEP2021-1912.34-C");
        assertEq(qToken.name(), "ROLLA WETH 04-September-2021 1912.34 Call");
    }

    function testCreateOptionsForEveryMonth() public {
        uint256 strikePrice = 2000 ether;
        uint256 expityTime = 1609773704;
        uint8[12] memory monthNameLengths = [7, 8, 5, 5, 3, 4, 4, 6, 9, 7, 8, 8];
        string[12] memory monthSymbols =
            ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
        string[12] memory monthNames = [
            "January",
            "February",
            "March",
            "April",
            "May",
            "June",
            "July",
            "August",
            "September",
            "October",
            "November",
            "December"
        ];

        for (uint256 i = 0; i < 12; i++) {
            (address qTokenAddress,) =
                optionsFactory.createOption(address(WETH), defaultOracle, uint88(expityTime), true, strikePrice);
            QToken qToken = QToken(qTokenAddress);

            string memory monthSymbol = OptionsUtils.slice(qToken.symbol(), 13, 16);
            string memory monthName = OptionsUtils.slice(qToken.name(), 14, 14 + uint256(monthNameLengths[i]));

            assertEq(monthSymbol, monthSymbols[i]);
            assertEq(monthName, monthNames[i]);

            expityTime += 31 days;
        }
    }

    function testEIP2612PermitConfiguration() public {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(defaultQToken.name())),
                keccak256("1"),
                block.chainid,
                address(defaultQToken)
            )
        );

        assertEq(domainSeparator, defaultQToken.DOMAIN_SEPARATOR());
    }

    function testEIP2612PermitConfiguration(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address oracle,
        uint32 expiryTime,
        bool isCall,
        uint256 strikePrice
    ) public {
        uint256 nameLength = bytes(name).length;
        uint256 symbolLength = bytes(symbol).length;
        vm.assume(nameLength > 0 && nameLength <= 15);
        vm.assume(symbolLength > 0 && symbolLength <= 15);
        vm.assume(oracle != address(0));
        strikePrice = bound(strikePrice, 1, type(uint256).max);
        expiryTime = uint32(bound(expiryTime, block.timestamp, type(uint88).max));

        ERC20 underlying = new ERC20(name, symbol, decimals);
        assetsRegistry.addAssetWithOptionalERC20Methods(address(underlying));

        (address qTokenAddress,) =
            optionsFactory.createOption(address(underlying), oracle, expiryTime, isCall, strikePrice);
        QToken qToken = QToken(qTokenAddress);

        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH, keccak256(bytes(qToken.name())), keccak256("1"), block.chainid, address(qToken)
            )
        );

        assertEq(domainSeparator, qToken.DOMAIN_SEPARATOR());
    }

    function testPermit() public {
        address owner = 0x31600b6eFf4b91F4ac2dA58Ee3076A6CBD54E6a3;
        uint256 ownerPrivKey = uint256(bytes32(0xba03f7828e0845c28f4eafc7991604090c151205f01bd08a0ed7f349e0a1b76e));

        address spender = address(5678);
        uint256 value = 5 ether;
        uint256 deadline = block.timestamp + 1 days;

        bytes32 permitHashedData = keccak256(
            abi.encodePacked(
                "\x19\x01",
                defaultQToken.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, defaultQToken.nonces(owner), deadline))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivKey, permitHashedData);

        vm.prank(spender);
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, spender, value);
        defaultQToken.permit(owner, spender, value, deadline, v, r, s);

        assertEq(defaultQToken.allowance(owner, spender), value);

        // mint some QToken to the owner
        defaultQToken.mint(owner, value);

        // transferFrom the owner as the spender
        vm.prank(spender);
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, spender, value);
        defaultQToken.transferFrom(owner, spender, value);

        assertEq(defaultQToken.balanceOf(owner), 0);
        assertEq(defaultQToken.balanceOf(spender), value);
        assertEq(defaultQToken.allowance(owner, spender), 0);
    }

    function testPermit(PermitTestArgs memory testArgs) public {
        uint256 nameLength = bytes(testArgs.name).length;
        uint256 symbolLength = bytes(testArgs.symbol).length;
        vm.assume(nameLength > 0 && nameLength <= 15);
        vm.assume(symbolLength > 0 && symbolLength <= 15);
        vm.assume(testArgs.oracle != address(0));
        testArgs.strikePrice = bound(testArgs.strikePrice, 1, type(uint256).max);
        testArgs.expiryTime = uint32(bound(testArgs.expiryTime, block.timestamp, type(uint32).max));
        testArgs.deadline = bound(testArgs.deadline, block.timestamp, type(uint256).max);
        testArgs.ownerPrivKey = bound(testArgs.ownerPrivKey, 1, SECP256K1_PRIV_KEY_LIMIT);
        address owner = vm.addr(testArgs.ownerPrivKey);

        ERC20 underlying = new ERC20(testArgs.name, testArgs.symbol, testArgs.decimals);
        assetsRegistry.addAssetWithOptionalERC20Methods(address(underlying));

        (address qTokenAddress,) = optionsFactory.createOption(
            address(underlying), testArgs.oracle, testArgs.expiryTime, testArgs.isCall, testArgs.strikePrice
        );
        QToken qToken = QToken(qTokenAddress);

        bytes32 permitHashedData = keccak256(
            abi.encodePacked(
                "\x19\x01",
                qToken.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        testArgs.spender,
                        testArgs.value,
                        qToken.nonces(owner),
                        testArgs.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(testArgs.ownerPrivKey, permitHashedData);

        vm.prank(testArgs.spender);
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, testArgs.spender, testArgs.value);
        qToken.permit(owner, testArgs.spender, testArgs.value, testArgs.deadline, v, r, s);

        assertEq(qToken.allowance(owner, testArgs.spender), testArgs.value);

        // mint some QToken to the owner
        qToken.mint(owner, testArgs.value);

        // transferFrom the owner as the spender
        vm.prank(testArgs.spender);
        vm.expectEmit(true, true, false, true);
        emit Transfer(owner, testArgs.spender, testArgs.value);
        qToken.transferFrom(owner, testArgs.spender, testArgs.value);

        assertEq(qToken.balanceOf(owner), 0);
        assertEq(qToken.balanceOf(testArgs.spender), testArgs.value);
        assertEq(qToken.allowance(owner, testArgs.spender), testArgs.value == type(uint256).max ? type(uint256).max : 0);
    }

    function testStrikePriceWithDecimals() public {
        uint256 decimalStrikePrice = 10000900010000000000000;
        uint88 expiryTime = 2153731385; // Thu Apr 01 2038 10:43:05 GMT+0000

        (address qTokenAddress,) =
            optionsFactory.createOption(address(WETH), defaultOracle, expiryTime, false, decimalStrikePrice);

        QToken qToken = QToken(qTokenAddress);

        assertEq(qToken.name(), "ROLLA WETH 01-April-2038 10000.90001 Put");
        assertEq(qToken.symbol(), "ROLLA-WETH-01APR2038-10000.90001-P");
    }

    function testWeiStrikePrice() public {
        uint256 weiStrikePrice = 1000000000000000001;
        uint88 expiryTime = 2153731385; // Thu Apr 01 2038 10:43:05 GMT+0000

        (address qTokenAddress,) =
            optionsFactory.createOption(address(WETH), defaultOracle, expiryTime, false, weiStrikePrice);

        QToken qToken = QToken(qTokenAddress);

        assertEq(qToken.name(), "ROLLA WETH 01-April-2038 1.000000000000000001 Put");
        assertEq(qToken.symbol(), "ROLLA-WETH-01APR2038-1.000000000000000001-P");
    }

    function testDogeDecimalStrikePrice() public {
        uint256 decimalStrikePrice = 135921000000000000;
        uint88 expiryTime = 2153731385; // Thu Apr 01 2038 10:43:05 GMT+0000

        (address qTokenAddress,) =
            optionsFactory.createOption(address(DOGE), defaultOracle, expiryTime, false, decimalStrikePrice);

        QToken qToken = QToken(qTokenAddress);

        assertEq(qToken.name(), "ROLLA DOGE 01-April-2038 0.135921 Put");
        assertEq(qToken.symbol(), "ROLLA-DOGE-01APR2038-0.135921-P");
    }

    function testCannotExecuteExpiredPermit(PermitTestArgs memory testArgs) public {
        uint256 nameLength = bytes(testArgs.name).length;
        uint256 symbolLength = bytes(testArgs.symbol).length;
        vm.assume(nameLength > 0 && nameLength <= 15);
        vm.assume(symbolLength > 0 && symbolLength <= 15);
        vm.assume(testArgs.oracle != address(0));
        testArgs.strikePrice = bound(testArgs.strikePrice, 1, type(uint256).max);
        testArgs.expiryTime = uint32(bound(testArgs.expiryTime, block.timestamp, type(uint32).max));
        testArgs.deadline = bound(testArgs.deadline, block.timestamp, type(uint256).max - 1);
        testArgs.ownerPrivKey = bound(testArgs.ownerPrivKey, 1, SECP256K1_PRIV_KEY_LIMIT);
        address owner = vm.addr(testArgs.ownerPrivKey);

        ERC20 underlying = new ERC20(testArgs.name, testArgs.symbol, testArgs.decimals);
        assetsRegistry.addAssetWithOptionalERC20Methods(address(underlying));

        (address qTokenAddress,) = optionsFactory.createOption(
            address(underlying), testArgs.oracle, testArgs.expiryTime, testArgs.isCall, testArgs.strikePrice
        );
        QToken qToken = QToken(qTokenAddress);

        bytes32 permitHashedData = keccak256(
            abi.encodePacked(
                "\x19\x01",
                qToken.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        testArgs.spender,
                        testArgs.value,
                        qToken.nonces(owner),
                        testArgs.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(testArgs.ownerPrivKey, permitHashedData);

        vm.warp(testArgs.deadline + 1);
        vm.prank(testArgs.spender);
        vm.expectRevert("PERMIT_DEADLINE_EXPIRED");
        qToken.permit(owner, testArgs.spender, testArgs.value, testArgs.deadline, v, r, s);
    }

    function testCannotExecutePermitWithInvalidSignature(PermitTestArgs memory testArgs) public {
        uint256 nameLength = bytes(testArgs.name).length;
        uint256 symbolLength = bytes(testArgs.symbol).length;
        vm.assume(nameLength > 0 && nameLength <= 15);
        vm.assume(symbolLength > 0 && symbolLength <= 15);
        vm.assume(testArgs.oracle != address(0));
        testArgs.strikePrice = bound(testArgs.strikePrice, 1, type(uint256).max);
        testArgs.expiryTime = uint32(bound(testArgs.expiryTime, block.timestamp, type(uint32).max));
        testArgs.deadline = bound(testArgs.deadline, block.timestamp, type(uint256).max);
        testArgs.ownerPrivKey = bound(testArgs.ownerPrivKey, 1, SECP256K1_PRIV_KEY_LIMIT);
        address owner = vm.addr(testArgs.ownerPrivKey);
        testArgs.otherPrivKey = bound(testArgs.otherPrivKey, 1, SECP256K1_PRIV_KEY_LIMIT);
        vm.assume(testArgs.otherPrivKey != testArgs.ownerPrivKey);

        ERC20 underlying = new ERC20(testArgs.name, testArgs.symbol, testArgs.decimals);
        assetsRegistry.addAssetWithOptionalERC20Methods(address(underlying));

        (address qTokenAddress,) = optionsFactory.createOption(
            address(underlying), testArgs.oracle, testArgs.expiryTime, testArgs.isCall, testArgs.strikePrice
        );
        QToken qToken = QToken(qTokenAddress);

        bytes32 permitHashedData = keccak256(
            abi.encodePacked(
                "\x19\x01",
                qToken.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        testArgs.spender,
                        testArgs.value,
                        qToken.nonces(owner),
                        testArgs.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(testArgs.otherPrivKey, permitHashedData);

        vm.prank(testArgs.spender);
        vm.expectRevert("INVALID_SIGNER");
        qToken.permit(owner, testArgs.spender, testArgs.value, testArgs.deadline, v, r, s);
    }

    function testApprove() public {
        address owner = address(1234);
        address spender = address(5678);
        uint256 value = 1000 ether;

        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, spender, value);
        defaultQToken.approve(spender, value);

        assertEq(defaultQToken.allowance(owner, spender), value);
    }

    // fuzz test for testApprove
    function testApproveFuzz(uint256 ownerPrivKey, uint256 spenderPrivKey, uint256 value) public {
        ownerPrivKey = bound(ownerPrivKey, 1, SECP256K1_PRIV_KEY_LIMIT);
        spenderPrivKey = bound(spenderPrivKey, 1, SECP256K1_PRIV_KEY_LIMIT);
        vm.assume(ownerPrivKey != spenderPrivKey);

        address owner = vm.addr(ownerPrivKey);
        address spender = vm.addr(spenderPrivKey);

        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit Approval(owner, spender, value);
        defaultQToken.approve(spender, value);

        assertEq(defaultQToken.allowance(owner, spender), value);
    }

    function testTransfer() public {
        address from = address(1234);
        address to = address(5678);
        uint256 value = 1000 ether;

        defaultQToken.mint(from, value);

        vm.prank(from);
        vm.expectEmit(true, true, false, true);
        emit Transfer(from, to, value);
        defaultQToken.transfer(to, value);

        assertEq(defaultQToken.balanceOf(from), 0);
        assertEq(defaultQToken.balanceOf(to), value);
    }

    // fuzz test for testTransfer
    function testTransferFuzz(uint256 fromPrivKey, uint256 toPrivKey, uint256 value) public {
        fromPrivKey = bound(fromPrivKey, 1, SECP256K1_PRIV_KEY_LIMIT);
        toPrivKey = bound(toPrivKey, 1, SECP256K1_PRIV_KEY_LIMIT);
        vm.assume(fromPrivKey != toPrivKey);

        address from = vm.addr(fromPrivKey);
        address to = vm.addr(toPrivKey);

        defaultQToken.mint(from, value);

        vm.prank(from);
        vm.expectEmit(true, true, false, true);
        emit Transfer(from, to, value);
        defaultQToken.transfer(to, value);

        assertEq(defaultQToken.balanceOf(from), 0);
        assertEq(defaultQToken.balanceOf(to), value);
    }
}
