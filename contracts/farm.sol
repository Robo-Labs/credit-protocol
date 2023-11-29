// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {LendingPool} from "contracts/pool.sol";

interface IFactory { 
    function isLoan(address _loan) external view returns(bool);
}

interface ILoan {
    function token() external view returns(address);
    function tokenId() external view returns(uint256);
    function fractionalize(uint256 _tokenIn, uint256 _amountLent) external;
    function deposits(uint256 _tokenId) external view returns(uint256);
    function withdrawals(uint256 _tokenId) external view returns(uint256);
    function withdraw(uint256 _tokenId) external; 
    function ownerOf(uint256 _tokenId) external view returns(address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function transfer(address to, uint256 tokenId) external;

}
// Masterchef provides multi-token rewards for the farms of RoboVault
// Contract is built on SteakHouseV2 used by Creditum team 
// This contract is forked from Popsicle.finance which is a fork of SushiSwap's MasterChef Contract
// It intakes one token and allows the user to farm another token. Due to the crosschain nature of Stake Steak we've swapped reward per block
// to reward per second. Moreover, we've implemented safe transfer of reward instead of mint in Masterchef.

// The contract is ownable untill the DAO will be able to take over.
contract MasterChef is Ownable {
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 RewardDebt; // Reward debt. See explanation below.
        uint256 RemainingRewards; // Reward Tokens that weren't distributed for user per pool.
        //
        // We do some fancy math here. Basically, any point in time, the amount of the given reward token
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.AccRewardsPerShare) - user.RewardDebt
        //
        // Whenever a user deposits or withdraws Staked tokens to a pool. Here's what happens:
        //   1. The pool's `AccRewardsPerShare` (and `lastRewardTime`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        address stakingToken; // Contract address of staked token
        uint256 stakingTokenTotalAmount; //Total amount of deposited tokens
        uint32 lastRewardTime; // Last timestamp number that Rewards distribution occurs.
        uint256 AccRewardsPerShare; // Accumulated reward tokens per share, times 1e12. See below.
        uint256 AllocPoints; // How many allocation points assigned to this pool. ROBO to distribute per second.
    }

    IERC20 public RewardToken;

    uint256 public RewardsPerSecond;

    uint256 public totalAllocPoints; // Total allocation points. Must be the sum of all allocation points in all pools.

    uint256 public startTime; // The timestamp when Rewards farming starts.

    uint256 public endTime; // Time on which the reward calculation should end

    uint256 public tokensPerSecondTime; // Time for setting rewards per second based on current balanace (can be utilised by keeper for single asset farms)

    bool public initialised = false; 

    address public factory;

    // Tracking depositor of NFT's for loans
    mapping(address => mapping(uint256 => address)) public loanOwner;

    PoolInfo[] private poolInfo; // Info of each pool.

    mapping(uint256 => mapping(address => UserInfo)) private userInfo; // Info of each user that stakes tokens.

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event FeeCollected(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        address _RewardToken,
        uint256 _RewardsPerSecond
    ) {
        RewardToken = IERC20(_RewardToken);
        RewardsPerSecond = _RewardsPerSecond;

    }

    /*
    modifier onlyKeeper() {
        require(
            owner() == _msgSender() ||
                keeper() == _msgSender(),
            "Authorized: caller is not the a keeper"
        );
        _;
    }
    function keeper() public view returns (address) {
        return _keeper;
    }

    function setKeeper(address newKeeper) external onlyOwner {
        _keeper = newKeeper;
        emit UpdateKeeper(_keeper);
    }
    */

    function setStartTime(uint256 _startTime) external onlyOwner{
        require(initialised == false);
        startTime = _startTime;
        endTime = _startTime + 30 days;
        initialised = true;
    }


    function changeEndTime(uint32 addSeconds) external onlyOwner {
        endTime += addSeconds;
    }

    // Owner can retreive excess/unclaimed Robo 7 days after endtime
    // Owner can NOT withdraw any token other than Robo
    function collect(uint256 _amount) external onlyOwner {
        require(block.timestamp >= endTime + 7 days, "too early to collect");
            uint256 balance = RewardToken.balanceOf(address(this));
            require(_amount <= balance, "withdrawing too much");
            RewardToken.safeTransfer(owner(), _amount);
        
    }

    // Changes token reward per second. Use this function to moderate the `lockup amount`. Essentially this function changes the amount of the reward
    // which is entitled to the user for his token staking by the time the `endTime` is passed.
    //Good practice to update pools without messing up the contract
    function setRewardsPerSecond(
        uint256 _rewardsPerSecond,
        bool _withUpdate
    ) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        RewardsPerSecond = _rewardsPerSecond;
    }


    function setTokensPerSecondTime(
        uint256 _tokensPerSecondTime
    ) external onlyOwner {
        tokensPerSecondTime = _tokensPerSecondTime;
    }

    // How many pools are in the contract
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function getPoolInfo(uint256 _pid) public view returns (PoolInfo memory) {
        return poolInfo[_pid];
    }

    function getUserInfo(uint256 _pid, address _user)
        public
        view
        returns (UserInfo memory)
    {
        return userInfo[_pid][_user];
    }

    // Add a new staking token to the pool. Can only be called by the owner.
    // VERY IMPORTANT NOTICE
    // ----------- DO NOT add the same staking token more than once. Rewards will be messed up if you do. -------------
    // Good practice to update pools without messing up the contract
    function add(
        uint256 _AllocPoints,
        address _loan,
        bool _withUpdate
    ) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }

        require(IFactory(factory).isLoan(_loan));
        uint256 lastRewardTime =
            block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoints += _AllocPoints;

        uint256 _pid = poolInfo.length;

        poolInfo.push(
            PoolInfo({
                stakingToken: _loan,
                stakingTokenTotalAmount: 0,
                lastRewardTime: uint32(lastRewardTime),
                AccRewardsPerShare:  uint256(0),
                AllocPoints: _AllocPoints
            })
        );

        //IFixedYield(_stakingToken).setFarmDetails(_pid);

    }

    // Update the given pool's allocation point per reward token. Can only be called by the owner.
    // Good practice to update pools without messing up the contract
    function set(
        uint256 _pid,
        uint256 _AllocPoints,
        bool _withUpdate
    ) external onlyOwner {

        if (_withUpdate) {
            massUpdatePools();
        }

        totalAllocPoints =
            totalAllocPoints -
            poolInfo[_pid].AllocPoints +
            _AllocPoints;
        poolInfo[_pid].AllocPoints = _AllocPoints;
        
    }

    // Return reward multiplier over the given _from to _to time.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        _from = _from > startTime ? _from : startTime;
        if (_from > endTime || _to < startTime) {
            return 0;
        }
        if (_to > endTime) {
            return endTime - _from;
        }
        return _to - _from;
    }

    // View function to see pending rewards on frontend.
    function pendingRewards(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 AccRewardsPerShare = pool.AccRewardsPerShare;
        uint256 PendingRewardToken;

        if (
            block.timestamp > pool.lastRewardTime &&
            pool.stakingTokenTotalAmount != 0
        ) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardTime, block.timestamp);
            if (totalAllocPoints != 0) {
                uint256 reward =
                    (multiplier *
                        RewardsPerSecond *
                        pool.AllocPoints) / totalAllocPoints;
                AccRewardsPerShare +=
                    (reward * 1e12) /
                    pool.stakingTokenTotalAmount;
            }
            
        }

        PendingRewardToken =
            (user.amount * AccRewardsPerShare) /
            1e12 -
            user.RewardDebt +
            user.RemainingRewards;
        
        return PendingRewardToken;
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() internal {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }

        if (pool.stakingTokenTotalAmount == 0) {
            pool.lastRewardTime = uint32(block.timestamp);
            return;
        }
        uint256 multiplier =
            getMultiplier(pool.lastRewardTime, block.timestamp);

        if (totalAllocPoints != 0) {
            uint256 reward =
                (multiplier * RewardsPerSecond * pool.AllocPoints) /
                    totalAllocPoints;
            pool.AccRewardsPerShare +=
                (reward * 1e12) /
                pool.stakingTokenTotalAmount;
            pool.lastRewardTime = uint32(block.timestamp);
        }
        
    }

    // Deposit staking tokens to the MasterChef for rewards allocation.
    function deposit(uint256 _pid, uint256 _tokenId, address _user) public {

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        address _loan = poolInfo[_pid].stakingToken;
        uint256 _amount = ILoan(_loan).deposits(_tokenId);
        require(ILoan(_loan).ownerOf(_tokenId) == msg.sender);
        ILoan(_loan).transferFrom(msg.sender, address(this), _tokenId);
        updatePool(_pid);
        loanOwner[_loan][_tokenId] = msg.sender;
        if (user.amount > 0) {
            uint256 pending =
                (user.amount * pool.AccRewardsPerShare) /
                    1e12 -
                    user.RewardDebt +
                    user.RemainingRewards;
            user.RemainingRewards = safeRewardTransfer(
                _user,
                pending
            );
        }

        uint256 amountToStake = _amount;
        user.amount += amountToStake;
        pool.stakingTokenTotalAmount += amountToStake;
        user.RewardDebt =
            (user.amount * pool.AccRewardsPerShare) /
            1e12;
        
        emit Deposit(msg.sender, _pid, amountToStake);
    }

    // Withdraw staked tokens from the MasterChef.
    function withdraw(uint256 _pid, uint256 _tokenId, address _user) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        address _loan = poolInfo[_pid].stakingToken;

        require(address(this) == ILoan(_loan).ownerOf(_tokenId));
        require(msg.sender == loanOwner[_loan][_tokenId]);
        uint256 _amount = ILoan(_loan).deposits(_tokenId);
        ILoan(_loan).transferFrom(address(this), msg.sender,  _tokenId);

        updatePool(_pid);
        uint256 pending =
            (user.amount * pool.AccRewardsPerShare) /
                1e12 -
                user.RewardDebt +
                user.RemainingRewards;
        user.RemainingRewards = safeRewardTransfer(
            _user,
            pending
        );
        user.amount -= _amount;
        pool.stakingTokenTotalAmount -= _amount;
        user.RewardDebt =
            (user.amount * pool.AccRewardsPerShare) /
            1e12;
        /*
        pool.stakingToken.safeTransfer(address(msg.sender), _amount);
        */
        emit Withdraw(_user, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid, address _user) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 userAmount = user.amount;
        user.amount = 0;
        user.RewardDebt = 0;
        user.RemainingRewards = 0;
        emit EmergencyWithdraw(msg.sender, _pid, userAmount);
    }

    // Safe reward token transfer function. Just in case if the pool does not have enough reward tokens,
    // The function returns the amount which is owed to the user
    function safeRewardTransfer(
        address _to,
        uint256 _amount
    ) internal returns (uint256) {
        uint256 rewardTokenBalance =
            RewardToken.balanceOf(address(this));
        if (rewardTokenBalance == 0) {
            //save some gas fee
            return _amount;
        }
        if (_amount > rewardTokenBalance) {

            RewardToken.safeTransfer(
                _to,
                rewardTokenBalance
            );
            return _amount - rewardTokenBalance;
        }
        RewardToken.safeTransfer(_to, _amount);
        return 0;
    }
}