// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

//import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendingPool} from "contracts/pool.sol";
//import {ILock} from "contracts/interfaces/ILock.sol";

interface ILock { 
    function backLoan(uint256 _amount, uint256 _loanNumber, address _user) external;
}

contract PoolFactory {

    struct backingInfo{
        uint256 loan;
        uint256 amount;
    }

    struct loanInfo{
        address _borrower;
        address _token;
        uint256 _maxLoan;
        uint256 _amountBacked;
        uint256[] _principleSchedule;
        uint256[] _paymentDeadline;
        uint256 _interestRate;
        uint256 _lateFee;

    }

    mapping(uint256 => loanInfo) public loanLookup;
    mapping(uint256 => mapping(address => uint256)) public backedLoans;
    mapping(uint256 => address) public loanAddress;
    mapping(uint256 => bool) public loanApproved;
    mapping(address => bool) public isLoan;

    uint256 loanCounter = 0;
    uint256 public minBacking;
    address public lockingContract;

    // function to propose loan terms 
    function proposeLoan(loanInfo memory _loan) external {
        loanLookup[loanCounter] = _loan;
        loanCounter += 1;
    }

    // function for stakers to back a loan
    function backLoan(uint256 _amount, uint256 _loanNumber) external {
        require(_loanNumber < loanCounter);
        require(loanApproved[_loanNumber]);
        ILock(lockingContract).backLoan(_amount, _loanNumber, msg.sender);
        //TO DO LOCK 
        backedLoans[_loanNumber][msg.sender] += _amount;
        loanLookup[_loanNumber]._amountBacked += _amount;
    }

    function unBackLoan(uint256 _amount, uint256 _loanNumber) external {
        require(_loanNumber < loanCounter);
        require(!loanApproved[_loanNumber]);
        //TO DO LOCK 
        backedLoans[_loanNumber][msg.sender] -= _amount;
        loanLookup[_loanNumber]._amountBacked -= _amount;
    }

    function createLoan(uint256 _loanNumber) external {
        require(loanLookup[_loanNumber]._amountBacked >= minBacking);
        
        loanInfo storage loan = loanLookup[_loanNumber];
        address newPool = address(new LendingPool("test", "test", loan._borrower, loan._token, loan._maxLoan, loan._principleSchedule, loan._principleSchedule, loan._interestRate, loan._lateFee));
        loanAddress[_loanNumber] = newPool;
        isLoan[newPool] = true;
    }

}