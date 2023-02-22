// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.18;

import "../src/options/CollateralToken.sol";
import "forge-std/Test.sol";

contract CollateralTokenTest is Test {
    CollateralToken collateralToken;
    address user = 0x31600b6eFf4b91F4ac2dA58Ee3076A6CBD54E6a3;
    uint256 userPrivKey = uint256(bytes32(0xba03f7828e0845c28f4eafc7991604090c151205f01bd08a0ed7f349e0a1b76e));
    address secondaryAccount = 0xf9e01860E3b4e1e7C840b3b2565935D60E2E276A;
    uint256 secondaryAccountPrivKey =
        uint256(bytes32(0x0eeba11b63268770497270ab548c90df2649fc3d9117685bc766cd74e763413c));

    address create2Deployer = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    bytes32 immutable EIP712_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    // keccak256(
    //     "metaSetApprovalForAll(address cTokenOwner,address operator,bool approved,uint256 nonce,uint256 deadline)"
    // );
    bytes32 immutable META_APPROVAL_TYPEHASH = 0x8733d126a676f1e83270eccfbe576f65af55d3ff784c4dc4884be48932f47c81;

    bytes32 COLLATERAL_TOKEN_DOMAIN_SEPARATOR;

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event CollateralTokenCreated(address indexed qTokenAddress, address qTokenAsCollateral, uint256 id);
    event TransferSingle(
        address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount
    );

    function createCollateralToken(address qToken, address qTokenAsCollateral) internal returns (uint256 cTokenId) {
        if (qTokenAsCollateral == address(0)) {
            cTokenId = collateralToken.createOptionCollateralToken(qToken);
        } else {
            cTokenId = collateralToken.createSpreadCollateralToken(qToken, qTokenAsCollateral);
        }
    }

    function constrainReceiver(address receiver) internal {
        uint256 receiverCodeSize;
        assembly {
            receiverCodeSize := extcodesize(receiver)
        }
        // make sure the receiver is not the zero address nor a contract,
        // which might not implement onERC1155Received
        vm.assume(receiver != address(0) && receiverCodeSize == 0);
    }

    function setUp() public {
        collateralToken = new CollateralToken("Quant Protocol", "1.0.0", "https://tokens.rolla.finance/{id}.json");

        // make it easier to test the CollateralToken onlyFactory functions
        collateralToken.setOptionsFactory(address(this));

        COLLATERAL_TOKEN_DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_TYPEHASH,
                keccak256(bytes("Quant Protocol")),
                keccak256(bytes("1.0.0")),
                block.chainid,
                address(collateralToken)
            )
        );
    }

    function testCannotMetaSetApprovalWithExpiredDeadline() public {
        vm.startPrank(user);

        vm.warp(block.timestamp + 3600);

        vm.expectRevert("CollateralToken: expired deadline");
        collateralToken.metaSetApprovalForAll(
            user, secondaryAccount, true, 0, block.timestamp - 2400, 0, bytes32(0), bytes32(0)
        );

        vm.stopPrank();
    }

    function testCannotMetaSetApprovalWithInvalidSignature() public {
        vm.startPrank(user);

        vm.expectRevert("ECDSA: invalid signature 'v' value");
        collateralToken.metaSetApprovalForAll(
            user, secondaryAccount, true, 0, block.timestamp + 3600, 0, bytes32(0), bytes32(0)
        );

        vm.stopPrank();
    }

    function testCannotMetaSetApprovalWithDifferentSigner(address operator, bool approved, uint256 deadline) public {
        vm.startPrank(secondaryAccount);

        deadline = bound(deadline, block.timestamp, type(uint256).max);
        uint256 nonce = collateralToken.nonces(secondaryAccount);

        bytes32 metaSetApprovalHashedData = keccak256(
            abi.encodePacked(
                "\x19\x01",
                COLLATERAL_TOKEN_DOMAIN_SEPARATOR,
                keccak256(abi.encode(META_APPROVAL_TYPEHASH, user, operator, approved, nonce, deadline))
            )
        );

        // sign the hashed data with the secondaryAccount instead of the expected user
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(secondaryAccountPrivKey, metaSetApprovalHashedData);

        vm.expectRevert("CollateralToken: invalid signature");
        collateralToken.metaSetApprovalForAll(user, operator, approved, nonce, deadline, v, r, s);
    }

    function testCannotMetaSetApprovalWithInvalidNonce() public {
        vm.startPrank(user);

        vm.expectRevert("CollateralToken: invalid nonce");
        collateralToken.metaSetApprovalForAll(
            user, secondaryAccount, true, 3, block.timestamp + 3600, 0, bytes32(0), bytes32(0)
        );

        vm.stopPrank();
    }

    function testMetaSetApprovalForAll(address operator, bool approved, uint256 deadline) public {
        vm.startPrank(secondaryAccount);

        deadline = bound(deadline, block.timestamp, type(uint256).max);
        uint256 nonce = collateralToken.nonces(user);

        bytes32 metaSetApprovalHashedData = keccak256(
            abi.encodePacked(
                "\x19\x01",
                COLLATERAL_TOKEN_DOMAIN_SEPARATOR,
                keccak256(abi.encode(META_APPROVAL_TYPEHASH, user, operator, approved, nonce, deadline))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivKey, metaSetApprovalHashedData);

        vm.expectEmit(true, true, false, true, address(collateralToken));
        emit ApprovalForAll(user, operator, approved);

        collateralToken.metaSetApprovalForAll(user, operator, approved, nonce, deadline, v, r, s);

        // check that the approval worked
        assertEq(collateralToken.isApprovedForAll(user, operator), approved);
        assertEq(collateralToken.nonces(user), nonce + 1);

        vm.stopPrank();
    }

    function testCreateOptionCollateralToken(address qToken) public {
        address qTokenAsCollateral = address(0);
        uint256 expectedId = collateralToken.getCollateralTokenId(qToken, address(0));
        vm.expectEmit(true, false, false, true, address(collateralToken));
        emit CollateralTokenCreated(qToken, qTokenAsCollateral, expectedId);

        uint256 actualId = collateralToken.createOptionCollateralToken(qToken);
        assertEq(expectedId, actualId);

        (address storedQTokenAddress, address storedQTokenAsCollateral) = collateralToken.idToInfo(actualId);
        assertEq(storedQTokenAddress, qToken);
        assertEq(storedQTokenAsCollateral, qTokenAsCollateral);
    }

    function testCannotCreateOptionCollateralTokenWithOtherAddresses(address qToken) public {
        vm.prank(user);
        vm.expectRevert("CollateralToken: caller is not OptionsFactory");
        collateralToken.createOptionCollateralToken(qToken);
    }

    function testCreateSpreadCollateralToken(address qToken, address qTokenAsCollateral) public {
        vm.assume(qToken != qTokenAsCollateral);
        uint256 expectedId = collateralToken.getCollateralTokenId(qToken, qTokenAsCollateral);
        vm.expectEmit(true, false, false, true, address(collateralToken));
        emit CollateralTokenCreated(qToken, qTokenAsCollateral, expectedId);

        uint256 actualId = collateralToken.createSpreadCollateralToken(qToken, qTokenAsCollateral);
        assertEq(expectedId, actualId);

        (address storedQTokenAddress, address storedQTokenAsCollateral) = collateralToken.idToInfo(actualId);
        assertEq(storedQTokenAddress, qToken);
        assertEq(storedQTokenAsCollateral, qTokenAsCollateral);
    }

    function testCannotCreateSpreadCollateralTokenWithOtherAddresses(address qToken, address qTokenAsCollateral)
        public
    {
        vm.prank(secondaryAccount);
        vm.expectRevert("Ownable: caller is not the owner");
        collateralToken.createSpreadCollateralToken(qToken, qTokenAsCollateral);
    }

    function testCannotCreateSpreadCollateralTokenWithDuplicateAddresses(address qToken) public {
        vm.expectRevert("CollateralToken: Can only create a collateral token with different tokens");
        collateralToken.createSpreadCollateralToken(qToken, qToken);
    }

    function testMintCollateralToken(address qToken, address qTokenAsCollateral, address receiver, uint256 mintAmount)
        public
    {
        vm.assume(qToken != qTokenAsCollateral || qTokenAsCollateral == address(0));
        constrainReceiver(receiver);

        uint256 cTokenId = createCollateralToken(qToken, qTokenAsCollateral);
        vm.expectEmit(true, true, true, true, address(collateralToken));
        emit TransferSingle(address(this), address(0), receiver, cTokenId, mintAmount);
        collateralToken.mintCollateralToken(receiver, cTokenId, mintAmount);
        assertEq(collateralToken.balanceOf(receiver, cTokenId), mintAmount);
    }

    function testCannotMintToTheZeroAddress(address qToken, address qTokenAsCollateral, uint256 mintAmount) public {
        vm.assume(qToken != qTokenAsCollateral || qTokenAsCollateral == address(0));

        uint256 cTokenId = createCollateralToken(qToken, qTokenAsCollateral);
        vm.expectRevert("UNSAFE_RECIPIENT");
        collateralToken.mintCollateralToken(address(0), cTokenId, mintAmount);
    }

    function testCannotMintWithUnauthorizedAccount(
        address qToken,
        address qTokenAsCollateral,
        address receiver,
        uint256 mintAmount
    ) public {
        vm.assume(qToken != qTokenAsCollateral || qTokenAsCollateral == address(0));

        uint256 cTokenId = createCollateralToken(qToken, qTokenAsCollateral);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(user);
        collateralToken.mintCollateralToken(receiver, cTokenId, mintAmount);
    }

    function testBurnCollateralToken(address qToken, address qTokenAsCollateral, address receiver, uint256 amount)
        public
    {
        vm.assume(qToken != qTokenAsCollateral || qTokenAsCollateral == address(0));
        constrainReceiver(receiver);

        uint256 cTokenId = createCollateralToken(qToken, qTokenAsCollateral);

        // before burning, mint the CollateralToken to the receiver
        collateralToken.mintCollateralToken(receiver, cTokenId, amount);
        assertEq(collateralToken.balanceOf(receiver, cTokenId), amount);

        vm.expectEmit(true, true, true, true, address(collateralToken));
        emit TransferSingle(address(this), receiver, address(0), cTokenId, amount);
        collateralToken.burnCollateralToken(receiver, cTokenId, amount);
        assertEq(collateralToken.balanceOf(receiver, cTokenId), 0);
    }

    function testCannotBurnMoreThanBalance(address qToken, address qTokenAsCollateral, address receiver, uint256 amount)
        public
    {
        vm.assume(qToken != qTokenAsCollateral || qTokenAsCollateral == address(0));
        constrainReceiver(receiver);
        amount = bound(amount, 1, type(uint256).max - 1);

        uint256 cTokenId = createCollateralToken(qToken, qTokenAsCollateral);

        // before burning, mint the CollateralToken to the receiver
        collateralToken.mintCollateralToken(receiver, cTokenId, amount);
        assertEq(collateralToken.balanceOf(receiver, cTokenId), amount);

        vm.expectRevert(stdError.arithmeticError);
        collateralToken.burnCollateralToken(receiver, cTokenId, amount + 1);
    }

    function testCannotBurnWithUnauthorizedAccount(
        address qToken,
        address qTokenAsCollateral,
        address receiver,
        uint256 amount
    ) public {
        vm.assume(qToken != qTokenAsCollateral || qTokenAsCollateral == address(0));
        constrainReceiver(receiver);

        uint256 cTokenId = createCollateralToken(qToken, qTokenAsCollateral);

        // before burning, mint the CollateralToken to the receiver
        collateralToken.mintCollateralToken(receiver, cTokenId, amount);
        assertEq(collateralToken.balanceOf(receiver, cTokenId), amount);

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(secondaryAccount);
        collateralToken.burnCollateralToken(receiver, cTokenId, amount);
    }

    function testConfiguredUri(string memory name, string memory symbol, string memory uri, uint256 id) public {
        CollateralToken cTokenWithUri = new CollateralToken(name, symbol, uri);
        assertEq(cTokenWithUri.uri(id), uri);
    }
}
