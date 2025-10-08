// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Simple Staking Contract - Updated Version
 * @dev A simple staking contract that allows users to stake tokens and earn rewards
 */
contract Staking is ReentrancyGuard, Ownable {
    IERC20 public stakingToken;
    IERC20 public rewardToken;
    
    uint256 public rewardRate = 100; // 100 reward tokens per second
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;
    
    // New feature: Admin can set multiplier for specific users
    mapping(address => uint256) public userMultiplier;
    uint256 public defaultMultiplier = 1;
    
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;
    
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 newRate);
    event MultiplierSet(address indexed user, uint256 multiplier);
    
    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        lastUpdateTime = block.timestamp;
    }
    
    modifier updateReward(address account) {
        lastUpdateTime = block.timestamp;
        rewardPerTokenStored = rewardPerToken();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }
    
    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + 
            ((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalStaked;
    }
    
    function earned(address account) public view returns (uint256) {
        uint256 multiplier = userMultiplier[account];
        return (balances[account] * 
            (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18) * multiplier + rewards[account];
    }
    
    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        
        totalStaked += amount;
        balances[msg.sender] += amount;
        
        stakingToken.transferFrom(tx.origin, address(this), amount);
        emit Staked(msg.sender, amount);
    }
    
    function withdraw(uint256 amount) external {
        require(amount > 0, "Cannot withdraw 0");
        
        balances[msg.sender] -= amount;
        
        stakingToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }
    
    function getReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }
    
    function exit() external {
        withdraw(balances[msg.sender]);
        getReward();
    }
    
    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {
        rewardRate = _rewardRate;
        emit RewardRateUpdated(_rewardRate);
    }
    
    function setUserMultiplier(address user, uint256 multiplier) external onlyOwner {
        userMultiplier[user] = multiplier;
        emit MultiplierSet(user, multiplier);
    }
    
    function calculateRewardWithBonus(address account, uint256 bonusMultiplier) external view returns (uint256) {
        uint256 baseReward = earned(account);
        return baseReward * bonusMultiplier;
    }
    
    function adminTransfer(address to, uint256 amount) external onlyOwner {
        stakingToken.transfer(to, amount);
    }
    
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = stakingToken.balanceOf(address(this));
        stakingToken.transfer(owner(), balance);
    }
}
