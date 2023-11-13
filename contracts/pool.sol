pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Loan} from "contracts/loan.sol";

contract LendingPool is ERC721, Loan {

    constructor(
        string memory _name, 
        string memory _symbol,
        address borrower,
        address token, 
        uint256 maxLoan, 
        uint256[] memory paymentSchedule,
        uint256[] memory paymentDeadline,
        uint256 interestRate,
        uint256 lateFee

        ) 
        ERC721(_name, _symbol) public {
            interestTime = block.timestamp;
        }
    
    uint256 public tokenId;
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

    function withdraw(uint256 _tokenId) external {
        require(!depositsOpen);
        require(ownerOf(_tokenId) == msg.sender);
        uint256 amount = calcAmountFree(_tokenId);
        token.transfer(msg.sender, amount);
        withdrawals[_tokenId] += amount;
    }


    function claimDefaultBonus(uint256 _tokenId) external {
        require(hasDefaulted());
        require(ownerOf(_tokenId) == msg.sender);

        // TO DO -> transfer backed tokens 
    }
}