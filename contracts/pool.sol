pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Loan} from "contracts/loan.sol";

interface ILock {
    function onDefault(uint256 _loanNumber) external;
    function onRepaidLoan(uint256 _loanNumber) external; 
}

interface IFactory {
    function loanAddress(address _loan) external view returns(uint256);
}

contract LendingPool is ERC721, Loan {

    constructor(
        string memory _name, 
        string memory _symbol,
        address _borrower,
        address _token, 
        uint256 _borrowLimit, 
        uint256[] memory _principleSchedule,
        uint256[] memory _paymentDeadline,
        uint256 _interestRate,
        uint256 _latePaymentRate,
        uint256 _nPayments

        ) 
        ERC721(_name, _symbol) public {
            interestTime = block.timestamp;
            //uint256 n = _principleSchedule.length(); 
            borrower = _borrower; 
            token = IERC20(_token);
            borrowLimit = _borrowLimit;
            principleSchedule = _principleSchedule;
            paymentDeadline = _paymentDeadline;
            interestRate = _interestRate;
            latePaymentRate = _latePaymentRate;
            //uint256 _nPayments = principleSchedule.length();
            nPayments = _nPayments;
            finalPaymentTime = _paymentDeadline[_nPayments-1];


        }

    modifier onlyLender() {
        require((msg.sender == keeper) || isLender(msg.sender));
        _;

    }
    function isLender(address _lender) public view returns(bool) {
        return(balanceOf(_lender) > 0 );
    }

    uint256 public tokenId;
    uint256 public loanNumber;
    address public keeper;
    address public locker;
    address public factory;
    // Tracking deposits & withdrawals by 
    mapping(uint256 => uint256) public deposits;
    mapping(uint256 => uint256) public withdrawals;

    // How much is available to be withdrawn 
    function calcAmountFree(uint256 _tokenId) public view returns(uint256) {
        if (totalLent == 0){
            return 0;
        }
        uint256 depositAmt = deposits[_tokenId];
        uint256 interestShareUsers = interestEarned * rateSharingLenders / decimalAdj;
        uint256 totalDue = depositAmt * (principleRepaid + interestShareUsers + latePayments) / totalLent;
        return (totalDue - withdrawals[_tokenId]);

    }

    // for users to provide liquidity 
    function deposit(uint256 _amount) external {
        require((_amount + totalLent) <= borrowLimit);
        require(depositsOpen);

        token.transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, tokenId);
        deposits[tokenId] = _amount;
        tokenId += 1;
        totalLent += _amount;

    }

    function repayNext() external {
        _repayNext(msg.sender);
        if ((paymentIndex == nPayments) && !loanFinal) {
            /// Loan to be finalised either trigger default or unbacking of loan 
            if(hasDefaulted()){
                defaulted = true;
                loanFinal = true;
                ILock(locker).onDefault(loanNumber);
            } else {
                defaulted = false;
                loanFinal = true;
                ILock(locker).onRepaidLoan(loanNumber);           
            }
        }
    }

    function withdraw(uint256 _tokenId) external {
        require(!depositsOpen);
        require(ownerOf(_tokenId) == msg.sender);
        uint256 amount = calcAmountFree(_tokenId);
        token.transfer(msg.sender, amount);
        withdrawals[_tokenId] += amount;
    }

    function triggerDefault() external {
        require(hasDefaulted());
        require(!loanFinal);
        defaulted = true;
        loanFinal = true;
        ILock(locker).onDefault(loanNumber);
    }

    function claimDefaultBonus(uint256 _tokenId) external {
        require(hasDefaulted());
        require(ownerOf(_tokenId) == msg.sender);

        // TO DO -> transfer backed tokens 
    }
}