// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILock {
    function onDefault(uint256 _loanNumber) external;
    function onRepaidLoan(uint256 _loanNumber) external; 
}

interface IFactory {
    function loanAddress(address _loan) external view returns(uint256);
}

abstract contract Loan {

    IERC20 public token;

    function isBorrower(address _sender) public view returns (bool) {
        require(_sender == borrower, "!borrower");
        return true;
    }

    modifier onlyBorrower() {
        isBorrower(msg.sender);
        _;
    }
    
    uint256 constant secondsPerYear = 31536000;
    uint256 constant decimalAdj = 10000;
    uint256 public tokenId;
    uint256 public loanNumber;
    address public locker;
    address public factory;
    bool public loanFinal = false;
    bool public loanRepaid = false;
    bool public depositsOpen = true;
    bool public defaulted = false; 

    uint256 public rateSharingLenders;
    // % of borrowed amount paid to backers 
    uint256 public finderFee;
    // % fee on principal repaid early (i.e. if decides to repay full loan before expiry)
    uint256 public minInterest; 
    // % additional rate on principal repaid late 
    uint256 public latePaymentRate; 

    uint256 public finalPaymentTime;

    uint256 public paymentIndex = 0;
    uint256 public nPayments;
    uint256[] public principleSchedule;
    uint256[] public paymentDeadline;

    uint256 public interestRate;
    // For tracking timestamp interest accumulates from 
    uint256 public interestTime;

    address public management;
    address public keeper;
    address public borrower;

    uint256 public borrowLimit;
    uint256 public totalLent = 0;
    uint256 public principleRepaid = 0;
    uint256 public principleWithdrawn = 0;
    uint256 public interestEarned = 0;
    uint256 public latePayments = 0;

    function hasDefaulted() public view returns (bool) {
        if (defaulted){
            return defaulted;
        }

        if (principleRepaid < totalLent){
            return(block.timestamp > finalPaymentTime);
        } else {
            return(false);
        }
    }

    function calcInterstDue() public view returns (uint256) { 
        uint256 totalOwed = totalLent - principleRepaid;
        return((totalOwed * interestRate / decimalAdj) * (block.timestamp - interestTime) / secondsPerYear );
    }

    function calcTotalDue() public view returns(uint256) {
        if (loanFinal){
            return 0;
        }
        uint256 interestDue = calcInterstDue();
        uint256 principalDue = totalLent - principleRepaid;
        uint256 latePayment = 0;
        uint256 timeNow = block.timestamp;
        uint256 i = paymentIndex;
        uint256 time = paymentDeadline[i];
        
        /*
        TO DO FIX CALCS! 
        while ((time > timeNow) && (i < nPayments)) {
            latePayment += ((principleSchedule[i] * totalLent / borrowLimit) * ( timeNow - time ) / secondsPerYear) * latePaymentRate / decimalAdj;
            i += 1;
        }
        */ 
        return (interestDue + principalDue + latePayment);
    }

    function closeLoan() external onlyBorrower {
        require(depositsOpen);
        depositsOpen = false;
    }

    function withdrawLentFunds() external onlyBorrower {
        uint256 _amountFree = totalLent - principleWithdrawn;
        token.transfer(borrower, _amountFree);
        principleWithdrawn += _amountFree;
    }


    // for borrower to make next scheduled repayment  
    function repayNext() external {
        require(!loanRepaid);
        if (depositsOpen){
            depositsOpen = false;
        }
        uint256 principleDue = principleSchedule[paymentIndex]* totalLent / borrowLimit; 
        uint256 interestDue = calcInterstDue();
        uint256 totalDue = principleDue + interestDue;

        uint256 deadline = paymentDeadline[paymentIndex];
        uint256 latePayment = 0;

        // Calc Late Payments 
        if (block.timestamp > deadline){
            latePayment = (principleDue*(block.timestamp - deadline) / secondsPerYear)* latePaymentRate / decimalAdj;
        }

        token.transferFrom(msg.sender, address(this) , totalDue + latePayment);
        paymentIndex += 1;

        if ((paymentIndex == nPayments) && !loanFinal) {
            /// Loan to be finalised either trigger default or unbacking of loan 
            loanRepaid = true;
            loanFinal = true;

            if(hasDefaulted()){
                defaulted = true;
                
                //ILock(locker).onDefault(loanNumber);
            } else {
                defaulted = false;
                // Note this can be called externally but breaks if called by loan contract ??? 
                //ILock(locker).onRepaidLoan(loanNumber);           
            }
        }        
        interestTime = block.timestamp;
        principleRepaid += principleDue;
        interestEarned += interestDue;
        latePayments += latePayment;
    }




}