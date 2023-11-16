// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolFactory} from "contracts/poolFactory.sol";

interface IFactory { 
    function isLoan(address _loan) external returns(bool);
}

contract LockingContract {

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
    mapping(address => mapping ( uint256 => uint256)) public userBacking;


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

    // BREAK THIS FOR TESTING 
    modifier onlyPool() {
        //require(isLoan(msg.sender));
        _;
    }

    function initialise(address _factory, address _token) external onlyGov {
        require(!initialised);
        factory = _factory;
        token = IERC20(_token);
        initialised = true;
    }

    function isLoan(address _loan) public returns(bool) {
        return(IFactory(factory).isLoan(_loan));
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


    function redeemLocked(uint256 _lockNumber) external {
        require(block.timestamp >= unlockTimes[_lockNumber]);
        uint256 amount = lockAmounts[_lockNumber];
        require((totalLocked[msg.sender] - totalBacked[msg.sender]) >= amount );
        token.transfer(msg.sender, lockAmounts[_lockNumber]);
        lockAmounts[_lockNumber] = 0;
        totalLocked[msg.sender] -= amount;
    }


    function backLoan(uint256 _amount, uint256 _loanNumber, address _user) external onlyFactory {
        require((totalLocked[_user] - totalBacked[_user]) >= _amount );
        totalBacked[_user] += _amount;
        userBacking[_user][_loanNumber] += _amount;
        backUsers[_loanNumber].push(_user);
        nBacked[_loanNumber] += 1;
    }

    function unbackLoan(uint256 _amount, uint256 _loanNumber, address _user) external onlyFactory {
        require(userBacking[_user][_loanNumber] >= _amount );
        totalBacked[_user] -= _amount;
        userBacking[_user][_loanNumber] -= _amount;
    }

    function onDefault(uint256 _loanNumber) external onlyPool {
        require(!loanFinalised[_loanNumber]);
        // Update Backing Numbers for user ~> should reset to 0 for loan
        uint256 i = 0;
        uint256 totalDefault = 0;
        while (i < nBacked[_loanNumber]){
            address _user = backUsers[_loanNumber][i];
            totalBacked[_user] -= userBacking[_user][_loanNumber];
            totalDefault += userBacking[_user][_loanNumber];
            userBacking[_user][_loanNumber] = 0;
            i += 1;
        }
        // Transfer ownership of locked tokens to pool ~> can use NFT to redeem 

        loanFinalised[_loanNumber] = true;

    }

    function onRepaidLoan(uint256 _loanNumber) external onlyPool {
        require(!loanFinalised[_loanNumber]);
        // Update Backing Numbers for user ~> should reset to 0 for loan
        uint256 i = 0;
        while (i < nBacked[_loanNumber]){
            address _user = backUsers[_loanNumber][i];
            totalBacked[_user] -= userBacking[_user][_loanNumber];
            userBacking[_user][_loanNumber] = 0;
            i += 1;

        }
        loanFinalised[_loanNumber] = true;
    }

}