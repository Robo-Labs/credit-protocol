// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

//import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LendingPool} from "contracts/pool.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//import {ILock} from "contracts/interfaces/ILock.sol";

interface ILock { 
    function backLoan(uint256 _amount, uint256 _loanNumber, address _user) external;
}

contract PoolFactory is ReentrancyGuard {

    struct backingInfo{
        uint256 loan;
        uint256 amount;
    }

    struct loanInfo{
        address _borrower;
        address _token;
        uint256 _minLoan;
        uint256 _maxLoan;
        uint256 _amountBacked;
        uint256[] _principleSchedule;
        uint256[] _paymentDeadline;
        uint256 _interestRate;
        uint256 _finderFee;
        uint256 _revShare;
        uint256 _timeOpen;
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
    mapping(uint256 => uint256) public loanDeadline;

    mapping(uint256 => bool) public loanApproved;
    mapping(address => bool) public isLoan;

    uint256 loanCounter = 0;
    uint256 public minBacking;
    // How long loan has to be approved once created
    uint256 public approvalTime = 10000;
    address public lockingContract;
    address public governance;

    function setLockingContract(address _locker) external onlyGov {
        lockingContract = _locker;
    }

    // Function to check if newly proposed loan is valid 
    function isValidLoan(loanInfo memory _loan) public returns(bool) {
        uint256 totalPayments = 0;
        uint256 n = _loan._nPayments;
        uint256 t = 0;
        for (uint i = 0; i < n; i++) {
            totalPayments += _loan._principleSchedule[i];
            require(_loan._paymentDeadline[i] >= t, "Repayments Unorderded");
            require(_loan._paymentDeadline[i] >= block.timestamp, "Repayment Date Too Late");

            t = _loan._paymentDeadline[i];
        }
        require(_loan._amountBacked == 0, "Amount Backed != 0");
        require(totalPayments == _loan._maxLoan, "Principal Unmatched");
        return true;
    }

    // function to propose loan terms 
    function proposeLoan(loanInfo memory _loan) external {
        require(isValidLoan(_loan));
        loanLookup[loanCounter] = _loan;
        loanDeadline[loanCounter] = block.timestamp + approvalTime;

        loanCounter += 1;

    }

    // function for stakers to back a loan
    function backLoan(uint256 _amount, uint256 _loanNumber) external {
        require(_loanNumber < loanCounter);
        require(!loanApproved[_loanNumber]);
        require(block.timestamp <= loanDeadline[_loanNumber]);
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

    function borrower(uint256 _loanNumber) public view returns(address) {
        return(loanLookup[_loanNumber]._borrower);
    }

    function token(uint256 _loanNumber) public view returns(address) {
        return(loanLookup[_loanNumber]._token);
    }

    function minLoan(uint256 _loanNumber) public view returns(uint256) {
        return(loanLookup[_loanNumber]._minLoan);
    }

    function maxLoan(uint256 _loanNumber) public view returns(uint256) {
        return(loanLookup[_loanNumber]._maxLoan);
    }

    function interestRate(uint256 _loanNumber) public view returns(uint256) {
        return(loanLookup[_loanNumber]._interestRate);
    }

    function nPayments(uint256 _loanNumber) public view returns(uint256) {
        return(loanLookup[_loanNumber]._nPayments);
    }

    function latePaymentRate(uint256 _loanNumber) public view returns(uint256) {
        return(loanLookup[_loanNumber]._lateFee);
    }

    function finderFeePct(uint256 _loanNumber) public view returns(uint256) {
        return(loanLookup[_loanNumber]._finderFee);
    }

    function revenueSharePct(uint256 _loanNumber) public view returns(uint256) {
        return(loanLookup[_loanNumber]._revShare);
    }

    function timeOpen(uint256 _loanNumber) public view returns(uint256) {
        return(loanLookup[_loanNumber]._timeOpen);
    }

    function amountBacked(uint256 _loanNumber) public view returns(uint256) {
        return(loanLookup[_loanNumber]._amountBacked);
    }


    function createLoan(uint256 _loanNumber) external {
        require(loanLookup[_loanNumber]._amountBacked >= minBacking);
        require(!loanApproved[_loanNumber]);
        require(block.timestamp <= loanDeadline[_loanNumber]);

        loanApproved[_loanNumber] = true;
        loanInfo storage _loan = loanLookup[_loanNumber];
        address newPool = address(new LendingPool(
            "test", 
            "test",
            address(this),
            _loanNumber,
            _loan._principleSchedule,
            _loan._paymentDeadline
            ));
        loanAddress[_loanNumber] = newPool;

        isLoan[newPool] = true;
    }

}