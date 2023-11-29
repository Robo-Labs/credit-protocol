pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Loan} from "contracts/loan.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface ILock {
    function onDefault(uint256 _loanNumber) external;
    function onRepaidLoan(uint256 _loanNumber) external; 
    function token() external view returns(address);
}

interface IFactory {
    function loanAddress(address _loan) external view returns(uint256);
    function borrower(uint256 _loanNumber) external view returns(address);
    function token(uint256 _loanNumber) external view returns(address);
    function minLoan(uint256 _loanNumber) external view returns(uint256);
    function maxLoan(uint256 _loanNumber) external view returns(uint256);
    function interestRate(uint256 _loanNumber) external view returns(uint256);
    function nPayments(uint256 _loanNumber) external view returns(uint256);
    function latePaymentRate(uint256 _loanNumber) external view returns(uint256);
    function finderFeePct(uint256 _loanNumber) external view returns(uint256);
    function revenueSharePct(uint256 _loanNumber) external view returns(uint256);
    function timeOpen(uint256 _loanNumber) external view returns(uint256);
    function lockingContract() external view returns(address);
    function amountBacked(uint256 _loanNumber) external view returns(uint256);
    function hasCollateral(uint256 _loanNumber) external view returns(bool);
    function collateralToken(uint256 _loanNumber) external view returns(address);
    function collateralAmount(uint256 _loanNumber) external view returns(uint256);


}

contract LendingPool is ERC721, Loan {

    constructor(
            string memory _name, 
            string memory _symbol,
            address _factory,
            uint256 _loanNumber,
            uint256[] memory _principleSchedule,
            uint256[] memory _paymentDeadline
        ) 
        ERC721(_name, _symbol) public {
            interestTime = block.timestamp;
            _init(_factory, _loanNumber);
            principleSchedule = _principleSchedule;
            paymentDeadline = _paymentDeadline;
            loanNumber = _loanNumber;
            finalPaymentTime = paymentDeadline[nPayments - 1];
    }

    function _init(address _factory, uint256 _loanNumber) internal {
        borrower = IFactory(_factory).borrower(_loanNumber);
        token = IERC20(IFactory(_factory).token(_loanNumber));
        interestRate = IFactory(_factory).interestRate(_loanNumber);
        minLoan = IFactory(_factory).minLoan(_loanNumber);
        maxLoan = IFactory(_factory).maxLoan(_loanNumber);
        interestRate = IFactory(_factory).interestRate(_loanNumber);
        nPayments = IFactory(_factory).nPayments(_loanNumber);
        latePaymentRate = IFactory(_factory).latePaymentRate(_loanNumber);
        finderFeePct = IFactory(_factory).finderFeePct(_loanNumber);
        //revenueSharePct = IFactory(_factory).revenueSharePct(_loanNumber);
        depositDeadline = IFactory(_factory).timeOpen(_loanNumber) + block.timestamp;
        locker = IFactory(_factory).lockingContract();
        amountLocked = IFactory(_factory).amountBacked(_loanNumber);
        if (IFactory(_factory).hasCollateral(_loanNumber)){
            hasCollateral = true;
            collateralToken = IFactory(_factory).collateralToken(_loanNumber);
            collateralAmt = IFactory(_factory).collateralAmount(_loanNumber);
        }
    }

    modifier onlyLender() {
        require(isLender(msg.sender));
        _;

    }
    function isLender(address _lender) public view returns(bool) {
        return(balanceOf(_lender) > 0 );
    }


    // Tracking deposits & withdrawals by 
    mapping(uint256 => uint256) public deposits;
    mapping(uint256 => uint256) public withdrawals;
    mapping(uint256 => bool) public claimedDefault;
    uint256 public tokenId;
    uint256 public amountLocked;

    // Tracking revenue claimed by lockers
    uint256 public revenueClaimed;

    // How much is available to be withdrawn 
    function calcAmountFree(uint256 _tokenId) public view returns(uint256) {
        if (totalLent == 0){
            return 0;
        }
        uint256 depositAmt = deposits[_tokenId];
        uint256 interestShareUsers = interestEarned * revenueSharePct / decimalAdj;
        uint256 totalDue = depositAmt * (principleRepaid + interestShareUsers + latePayments) / totalLent;
        return (totalDue - withdrawals[_tokenId]);
    }

    // used to fractionalize NFT's to different amounts 
    function fractionalize(uint256 _tokenIn, uint256 _amountLent) external nonReentrant {
        require(msg.sender ==  ownerOf(_tokenIn));
        uint256 principleWithdrawn = withdrawals[_tokenIn];
        uint256 amountBurn = deposits[_tokenIn];
        require(_amountLent <= amountBurn);

        _burn(_tokenIn);
        // Mint new NFT with amount matching _amountLent
        _mint(msg.sender, tokenId);
        deposits[tokenId] = _amountLent;
        withdrawals[tokenId] = principleWithdrawn * _amountLent / amountBurn;
        tokenId += 1;
        // Mint new NFT with rights to remaining amount
        _mint(msg.sender, tokenId);
        deposits[tokenId] = amountBurn - _amountLent;
        withdrawals[tokenId] = principleWithdrawn - withdrawals[tokenId - 1];
        tokenId += 1;        

    }

    // for users to provide liquidity 
    function deposit(uint256 _amount) external nonReentrant {
        require((_amount + totalLent) <= maxLoan);
        require(depositsOpen);

        token.transferFrom(msg.sender, address(this), _amount);
        _mint(msg.sender, tokenId);
        deposits[tokenId] = _amount;
        tokenId += 1;
        totalLent += _amount;

    }

    function withdraw(uint256 _tokenId) external nonReentrant {
        require(!depositsOpen);
        require(ownerOf(_tokenId) == msg.sender);
        uint256 amount = calcAmountFree(_tokenId);
        token.transfer(msg.sender, amount);
        withdrawals[_tokenId] += amount;
    }

    function triggerDefault() external nonReentrant {
        require(hasDefaulted());
        require(!loanFinal);
        require(block.timestamp >= finalPaymentTime);
        ILock(locker).onDefault(loanNumber);
        defaulted = true;
        loanFinal = true;
    }

    function triggerFinal() external nonReentrant {
        require(!hasDefaulted());
        require(loanRepaid);
        require(loanFinal);
        //require(block.timestamp >= finalPaymentTime);
        ILock(locker).onRepaidLoan(loanNumber);
        if (hasCollateral){
            IERC20(collateralToken).transfer(borrower, amount);
        }
        defaulted = false;
        loanFinal = true;
    }

    function claimDefaultBonus(uint256 _tokenId) external nonReentrant {
        require(hasDefaulted());
        require(loanFinal);
        require(ownerOf(_tokenId) == msg.sender);
        require(!claimedDefault[_tokenId]);
        uint256 _amount = amountLocked * deposits[_tokenId] / totalLent;
        // TO DO check if already withdrawn default bonus ~ store bool if claimed or not 
        IERC20(ILock(locker).token()).transfer(msg.sender, _amount);

        if (hasCollateral){
            uint256 _userCollat = collateralAmt * deposits[_tokenId] / totalLent;
            IERC20(collateralToken).transfer(msg.sender, _userCollat);
        }

        claimedDefault[_tokenId] = true;

    }

    function calcLockingRevenue() public view returns(uint256) {
        uint256 revenueEarned = interestEarned * revenueSharePct / decimalAdj;
        return (revenueEarned - revenueClaimed);
    }

    function claimLockingRevenue() external nonReentrant {
        require(msg.sender == locker);
        uint256 amount = calcLockingRevenue();
        token.transfer(locker, amount);
        revenueClaimed += amount;
    }

}