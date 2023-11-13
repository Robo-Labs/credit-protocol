// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolFactory} from "contracts/poolFactory.sol";


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

    mapping(uint256 => uint256) public lockAmounts;
    mapping(uint256 => uint256) public unlockTimes;
    mapping(uint256 => address) public lockUsers;
    mapping(address => uint256) public totalLocked;
    mapping(address => uint256) public totalBacked;

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

    function initialise(address _factory, address _token) external onlyGov {
        require(!initialised);
        factory = _factory;
        token = IERC20(_token);
        initialised = true;
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
    }

}