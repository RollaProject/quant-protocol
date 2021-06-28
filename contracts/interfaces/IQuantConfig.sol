// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./ITimelockedConfig.sol";
import "./external/openzeppelin/IAccessControl.sol";

// solhint-disable-next-line no-empty-blocks
interface IQuantConfig is ITimelockedConfig, IAccessControl {

}
