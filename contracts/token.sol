// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {

    //uint8 constant decimals = 18;
    uint256 public maxSupply = 1000000 * (10^18); 
    address public governance;

    modifier onlyGov() {
        require(msg.sender == governance);
        _;
    }

    constructor(string memory name_, string memory symbol_, address governance_) 
        ERC20(name_, symbol_)
     {
        governance = governance_;
     }
        

    function mint(address account, uint256 amount) external onlyGov {
        require(totalSupply() <= (maxSupply + amount));
        _mint(account, amount);
    }

    function transferGov(address _newGov) external onlyGov {
        governance = _newGov;
    }

}
