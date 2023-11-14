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
        uint256 _nPayments;

    }

    constructor(address _gov)  {
        governance = _gov;
    }

    modifier onlyGov() {
        require(msg.sender == governance);
        _;

    }

    mapping(uint256 => loanInfo) public loanLookup;
    mapping(uint256 => mapping(address => uint256)) public backedLoans;
    mapping(uint256 => address) public loanAddress;
    mapping(uint256 => bool) public loanApproved;
    mapping(address => bool) public isLoan;

    uint256 loanCounter = 0;
    uint256 public minBacking;
    address public lockingContract;
    address public governance;

    function setLockingContract(address _locker) external onlyGov {
        lockingContract = _locker;
    }

    // Function to check if newly proposed loan is valid 
    function _isValidLoan(loanInfo memory _loan) internal returns(bool) {
        uint256 totalPayments = 0;
        uint256 n = _loan._nPayments;

        for (uint i = 0; i < n; i++) {
            totalPayments += _loan._principleSchedule[i];
            
        }
        require(_loan._paymentDeadline[n - 1] > block.timestamp);
        require(_loan._amountBacked == 0);
    }

    // function to propose loan terms 
    function proposeLoan(loanInfo memory _loan) external {
        require(_isValidLoan(_loan));
        loanLookup[loanCounter] = _loan;
        loanCounter += 1;
    }

    // function for stakers to back a loan
    function backLoan(uint256 _amount, uint256 _loanNumber) external {
        require(_loanNumber < loanCounter);
        require(!loanApproved[_loanNumber]);
        ILock(lockingContract).backLoan(_amount, _loanNumber, msg.sender);
        backedLoans[_loanNumber][msg.sender] += _amount;
        loanLookup[_loanNumber]._amountBacked += _amount;
    }

    function unBackLoan(uint256 _amount, uint256 _loanNumber) external {
        require(_loanNumber < loanCounter);
        require(!loanApproved[_loanNumber]);
        backedLoans[_loanNumber][msg.sender] -= _amount;
        loanLookup[_loanNumber]._amountBacked -= _amount;
    }

    function createLoan(uint256 _loanNumber) external {
        require(loanLookup[_loanNumber]._amountBacked >= minBacking);
        require(!loanApproved[_loanNumber]);
        loanApproved[_loanNumber] = true;
        loanInfo storage loan = loanLookup[_loanNumber];
        address newPool = address(new LendingPool("test", "test", loan._borrower, loan._token, loan._maxLoan, loan._principleSchedule, loan._principleSchedule, loan._interestRate, loan._lateFee, loan._nPayments));
        loanAddress[_loanNumber] = newPool;
        isLoan[newPool] = true;
    }

}