// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ILock {
    function onDefault(uint256 _loanNumber) external;
    function onRepaidLoan(uint256 _loanNumber) external; 
}



abstract contract Loan is ReentrancyGuard {

    IERC20 public token;

    function isBorrower(address _sender) public view returns (bool) {
        require(_sender == borrower, "!borrower");
        return true;
    }

    modifier onlyBorrower() {
        isBorrower(msg.sender);
        _;
    }


    mapping(address => uint256) public backerWithdrawals;

    uint256 constant secondsPerYear = 31536000;
    uint256 constant decimalAdj = 10000;
    uint256 public loanNumber;
    address public locker;
    address public factory;
    bool public loanFinal = false;
    bool public loanRepaid = false;
    bool public depositsOpen = true;
    bool public defaulted = false; 
    bool public hasCollateral = false; 
    address public collateralToken;
    uint256 public collateralAmt;

    // share of revenue for backers 
    uint256 public revenueSharePct = 500;
    // % of borrowed amount paid to backers 
    uint256 public finderFeePct;
    // % fee on principal repaid early (i.e. if decides to repay full loan before expiry)
    uint256 public minInterest; 
    // % additional rate on principal repaid late 
    uint256 public latePaymentRate; 

    uint256 public depositDeadline;

    uint256 public finalPaymentTime;

    uint256 public paymentIndex = 0;
    uint256 public nPayments;
    uint256[] public principleSchedule;
    uint256[] public paymentDeadline;

    uint256 public interestRate;
    // For tracking timestamp interest accumulates from 
    uint256 public interestTime;

    address public management;
    address public borrower;

    uint256 public maxLoan;
    uint256 public minLoan;

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
        
        
        while ((timeNow > time) && (i < nPayments)) {
            latePayment += ((principleSchedule[i] * totalLent / maxLoan) * ( timeNow - time ) / secondsPerYear) * latePaymentRate / decimalAdj;
            i += 1;
            time = paymentDeadline[i];
        }

        return (interestDue + principalDue + latePayment);
    }

    function closeLoan() external nonReentrant onlyBorrower {
        require(depositsOpen);
        depositsOpen = false;
    }

    function withdrawLentFunds() external nonReentrant onlyBorrower {
        uint256 _amountFree = totalLent - principleWithdrawn;
        uint256 _finderFee = _amountFree * finderFeePct / decimalAdj;
        token.transfer(borrower, (_amountFree - _finderFee));
        principleWithdrawn += _amountFree;
    }

    // If minimium amount is not reached borrower can cancel loan & lenders can withdraw 
    function cancelLoan() external nonReentrant onlyBorrower {
        require(block.timestamp >= depositDeadline);
        require(totalLent < minLoan);

        loanRepaid = true; 
        loanFinal = true;
        defaulted = false; 
        depositsOpen = false;

        principleRepaid = totalLent;
        interestEarned = 0;
        latePayments = 0;
        // TO DO -> lenders can withdraw / mark loan as finalised 
        // TO DO -> unlock backing funds (min amount not reached)
    }


    // Allows borrower to swap collatearl out for 
    function liquidateCollateralAndRepay(uint256 _collatOut, uint256 _amountIn, address _liquidator) external onlyBorrower {
        if (depositsOpen){
            depositsOpen = false;
        }
        uint256 _amountDue = calcTotalDue();
        uint256 _interestDue = calcInterstDue();
        require(_amountIn >= _amountDue);

        token.transferFrom(_liquidator, address(this), _amountIn);
        IERC20(collateralToken).transfer(_liquidator, _collatOut);
        
        // Calc Late Payments 
        uint256 latePayment = _amountDue - _interestDue - (totalLent - principleRepaid);

        interestEarned += _interestDue;
        principleRepaid = totalLent; 
        latePayments += latePayment;

        loanRepaid = true;
        loanFinal = true;        
        paymentIndex =  nPayments;
        if(hasDefaulted()){
            defaulted = true;
            
            //ILock(locker).onDefault(loanNumber);
        } else {
            defaulted = false;
            if (hasCollateral && (_collatOut < collateralAmt)){
                IERC20(collateralToken).transfer(borrower, collateralAmt - _collatOut);
            }        
            if (_amountIn > _amountDue){
                token.transfer(borrower, _amountDue - _amountIn);
            }
        }

    }

    // for borrower to make next scheduled repayment  
    function repayNext() external nonReentrant {
        require(!loanRepaid);
        if (depositsOpen){
            depositsOpen = false;
        }
        uint256 principleDue = principleSchedule[paymentIndex]* totalLent / maxLoan; 
        uint256 interestDue = calcInterstDue();
        uint256 totalDue = principleDue + interestDue;

        uint256 deadline = paymentDeadline[paymentIndex];
        uint256 latePayment = 0;

        
        // Calc Late Payments 
        if (block.timestamp > deadline){
            latePayment = ((principleDue*totalLent / maxLoan) * (block.timestamp - deadline) / secondsPerYear)* latePaymentRate / decimalAdj;
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
                if (hasCollateral){
                    IERC20(collateralToken).transfer(borrower, collateralAmt);
                }
                //ILock(locker).onRepaidLoan(loanNumber);           
            }
        }        
        interestTime = block.timestamp;
        principleRepaid += principleDue;
        interestEarned += interestDue;
        latePayments += latePayment;
    }




}