// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface ILock { 
    function backLoan(uint256 _amount, uint256 _loanNumber, address _user) external;
}