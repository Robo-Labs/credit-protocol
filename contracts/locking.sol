// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolFactory} from "contracts/poolFactory.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";


interface IFactory { 
    function isLoan(address _loan) external view returns(bool);
    function loanAddress(uint256 _loanNumber) external view returns(address);
    function amountBacked(uint256 _loanNumber) external view returns(uint256);

}

interface ILoan {
    function loanFinal() external view returns(bool);
    function claimLockingRevenue() external;
    function token() external view returns(address);
    function calcLockingRevenue() external view returns(uint256);
}

contract LockingContract is ReentrancyGuard {

    IERC20 public token;
    address public governance;
    address public factory;
    uint256 internal lockCounter;



    // 2 Weeks
    uint256 internal minLock = 604800*2;
    // 2 Years
    uint256 public maxLock = 31536000*2;
    bool public initialised = false;

    mapping(uint256 => bool) public loanFinalised;
    mapping(uint256 => address[]) public backUsers;
    mapping(uint256 => uint256) public nBacked;
    mapping(uint256 => uint256) public lockAmounts;
    mapping(uint256 => uint256) public unlockTimes;
    mapping(uint256 => address) public lockUsers;
    mapping(address => uint256) public totalLocked;
    mapping(address => uint256) public totalBacked;
    mapping(uint256 => uint256) public totalBackedLoan;
    mapping(uint256 => uint256) public totalRevenue;
    mapping(address => mapping ( uint256 => uint256)) public userBacking;
    mapping(address => mapping ( uint256 => uint256)) public revenueClaimed;


    constructor(address _gov) public {
        governance = _gov;
    }

    modifier onlyGov() {
        require(msg.sender == governance);
        _;

    }

    modifier onlyFactory() {
        require(msg.sender == factory);
        _;
    }

    modifier onlyPool() {
        require(isLoan(msg.sender));
        _;
    }

    function initialise(address _factory, address _token) external onlyGov {
        require(!initialised);
        factory = _factory;
        token = IERC20(_token);
        initialised = true;
    }

    function isLoan(address _loan) public view returns(bool) {
        return(IFactory(factory).isLoan(_loan));
    }

    function loanAddress(uint256 _loanNumber) public view returns(address) {
        return IFactory(factory).loanAddress(_loanNumber);
    }

    function lockTokens(uint256 _amount, uint256 _duration) external {
        require(_duration >= minLock);
        require(_duration <= maxLock);
        token.transferFrom(msg.sender, address(this), _amount);
        lockAmounts[lockCounter] = _amount;
        unlockTimes[lockCounter] = block.timestamp + _duration;
        lockUsers[lockCounter] = msg.sender;
        totalLocked[msg.sender] += _amount;
        
    }


    function redeemLocked(uint256 _lockNumber) external nonReentrant {
        require(block.timestamp >= unlockTimes[_lockNumber]);
        uint256 amount = lockAmounts[_lockNumber];
        require((totalLocked[msg.sender] - totalBacked[msg.sender]) >= amount );
        token.transfer(msg.sender, lockAmounts[_lockNumber]);
        lockAmounts[_lockNumber] = 0;
        totalLocked[msg.sender] -= amount;
    }


    function backLoan(uint256 _amount, uint256 _loanNumber, address _user) external nonReentrant onlyFactory {
        require((totalLocked[_user] - totalBacked[_user]) >= _amount );
        totalBacked[_user] += _amount;
        userBacking[_user][_loanNumber] += _amount;
        backUsers[_loanNumber].push(_user);
        nBacked[_loanNumber] += 1;
    }

    function unbackLoan(uint256 _amount, uint256 _loanNumber, address _user) external nonReentrant onlyFactory {
        require(userBacking[_user][_loanNumber] >= _amount );
        totalBacked[_user] -= _amount;
        userBacking[_user][_loanNumber] -= _amount;
    }

    function claimRevenues(uint256 _loanNumber) external nonReentrant {
        address loan = loanAddress(_loanNumber);
        uint256 amountFree = ILoan(loan).calcLockingRevenue();
        if (amountFree > 0 ){
            ILoan(loan).claimLockingRevenue();
            totalRevenue[_loanNumber] += amountFree;
        }
        uint256 userRevenue = (totalRevenue[_loanNumber] * totalBacked[msg.sender] / IFactory(factory).amountBacked(_loanNumber)) - revenueClaimed[msg.sender][_loanNumber]; 
        IERC20(ILoan(loan).token()).transfer(msg.sender, userRevenue);
        revenueClaimed[msg.sender][_loanNumber] += userRevenue;
    }


    function onDefault(uint256 _loanNumber) external nonReentrant onlyPool {
        // Update Backing Numbers for user ~> should reset to 0 for loan
        uint256 i = 0;
        uint256 defaultOut = 0;
        while (i < nBacked[_loanNumber]){
            address _user = backUsers[_loanNumber][i];
            totalBacked[_user] -= userBacking[_user][_loanNumber];
            totalLocked[_user] -= userBacking[_user][_loanNumber];
            defaultOut += userBacking[_user][_loanNumber];
            userBacking[_user][_loanNumber] = 0;
            i += 1;
        }
        // Transfer ownership of locked tokens to pool ~> can use NFT to redeem 
        token.transfer(msg.sender, defaultOut);

    }

    function onRepaidLoan(uint256 _loanNumber) external nonReentrant onlyPool {
        // Update Backing Numbers for user ~> should reset to 0 for loan
        uint256 i = 0;
        while (i < nBacked[_loanNumber]){
            address _user = backUsers[_loanNumber][i];
            totalBacked[_user] -= userBacking[_user][_loanNumber];
            userBacking[_user][_loanNumber] = 0;
            i += 1;
        }
    }

}