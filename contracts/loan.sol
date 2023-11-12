// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    bool public loanRepaid = false;
    bool public depositsOpen = true;

    uint256 public rateSharingLenders;
    // % of borrowed amount paid to backers 
    uint256 public finderFee;
    // % fee on principal repaid early (i.e. if decides to repay full loan before expiry)
    uint256 public earlyRepayFee; 
    // % additional rate on principal repaid late 
    uint256 public latePaymentRate; 

    uint256 public paymentIndex = 0;
    uint256 public nPayments;
    uint256[] public interestSchedule;
    uint256[] public principleSchedule;
    uint256[] public paymentDeadline;

    address public management;
    address public keeper;
    address public borrower;

    uint256 public borrowLimit;
    uint256 public totalLent = 0;
    uint256 public principleRepaid = 0;
    uint256 public interestEarned = 0;
    uint256 public latePayments = 0;

    function hasDefaulted() public returns (bool) {

    }

    function triggerDefault() external virtual {
        require(hasDefaulted() == true);
        // TO DO THIS SHOULD SLASH BACKERS 
    }


    // for borrower to make next scheduled repayment  
    function repay() external {
        require(!loanRepaid);
        if (depositsOpen){
            depositsOpen = false;
        }
        uint256 principleDue = principleSchedule[paymentIndex]* totalLent / borrowLimit; 
        uint256 interestDue = interestSchedule[paymentIndex]* totalLent / borrowLimit; 
        uint256 totalDue = principleDue + interestDue;

        uint256 deadline = paymentDeadline[paymentIndex];
        uint256 latePayment = 0;

        if (block.timestamp > deadline){
            latePayment = totalDue*((block.timestamp - deadline) / secondsPerYear) * (latePaymentRate / decimalAdj);
        }

        token.transferFrom(msg.sender, address(this) , totalDue + latePayment);
        paymentIndex += 1;
        if (paymentIndex == nPayments){
            loanRepaid = true;
        }

        principleRepaid += principleDue;
        interestEarned += interestDue;
        latePayments += latePayment;
    }

    function repayPartial(uint256 _amount) external {
        require(!loanRepaid);
        if (depositsOpen){
            depositsOpen = false;
        }

        uint256 amount = _amount;

        while ((amount > 0) && (paymentIndex < nPayments)) {
            uint256 principleDue = principleSchedule[paymentIndex]* totalLent / borrowLimit; 
            uint256 interestDue = interestSchedule[paymentIndex]* totalLent / borrowLimit; 
            uint256 totalDue = principleDue + interestDue;

            uint256 deadline = paymentDeadline[paymentIndex];
            uint256 latePayment = 0;

            if (block.timestamp > deadline){
                latePayment = totalDue*((block.timestamp - deadline) / secondsPerYear) * (latePaymentRate / decimalAdj);
            }

            if (amount >= (totalDue + latePayment)) {
                paymentIndex += 1;
                principleRepaid += principleDue;
                interestEarned += interestDue;
                latePayments += latePayment;
                amount -= (totalDue + latePayment);
            } else {
                uint256 principleAdj = principleSchedule[paymentIndex]* amount / totalDue;
                uint256 interestAdj = interestSchedule[paymentIndex]* amount / totalDue;
                principleSchedule[paymentIndex] -= principleAdj;
                interestSchedule[paymentIndex] -= interestAdj;
                principleRepaid += principleAdj;
                interestEarned += interestAdj;
                latePayments += latePayment*amount / totalDue;
                amount = 0;                
            }


        }

    }


}