pragma solidity ^0.7.6;

/// @title Title
/// @author Author
/// @notice Contract notice
/// @dev Contract dev
contract ExampleContract {
    /// @notice Function notice
    /// @dev Function dev
    /// @param paramName function param
    /// @return returnVal function return val
    function exampleFunction(uint256 paramName)
        external
        pure
        returns (uint256)
    {
        return paramName + 1;
    }
}
