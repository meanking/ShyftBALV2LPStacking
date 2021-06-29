//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ShyftBALV2LPStaking is Ownable {
  using SafeERC20 for IERC20;
  using SafeMath  for uint256;

  uint256 public secondsAWeek = 7 * 24 * 60 * 60; // Seconds for a week
  IERC20  public shyftToken; // Shyft token

  struct PoolData {
    IERC20 lpToken;
    uint256 numShyftPerWeek;
  }
  struct UserData {
    uint256 lpAmount;
    uint256 lastClaimDate;
  }
  
  PoolData[] public poolData;
  mapping (uint256 => mapping (address => UserData)) public userData;

  event Deposited(
    address indexed _from,
    uint256 indexed _id,
    uint256 _amount
  );

  event Withdrew(
    address indexed _to,
    uint256 indexed _id,
    uint256 _amount
  );

  constructor(
    IERC20 _shyftToken
  ) {
    shyftToken = _shyftToken;
  }
  
  // Add a new Balancer Pool
  function addPool(
    IERC20 _balLPToken, 
    uint256 _numShyftPerWeek
  ) public onlyOwner {
    poolData.push(PoolData({
      lpToken: _balLPToken,
      numShyftPerWeek: _numShyftPerWeek
    }));
  }
  
  // Change numShyftPerWeek for a sepcific Balancer Pool
  function changeNumShyftPerWeek(
    uint256 _balPoolId,
    uint256 _numShyftPerWeek
  ) public onlyOwner {
    PoolData storage pool = poolData[_balPoolId];
    pool.numShyftPerWeek = _numShyftPerWeek;
  }
  
  // Get pending reward for a user
  function pendingReward(
    uint256 _balPoolId,
    uint256 _currentDate
  ) public view returns (uint256 pendingAmount) {
    UserData storage user = userData[_balPoolId][msg.sender];
    if (user.lpAmount > 0 && user.lastClaimDate > 0) {
      pendingAmount = claimCalculation(_balPoolId, _currentDate).div(1e18);
    }
  }
  
  // Claim reward for a user
  function claim(
    uint256 _balPoolId,
    uint256 _currentDate
  ) external {
    UserData storage user = userData[_balPoolId][msg.sender];
    if (user.lpAmount > 0 && user.lastClaimDate > 0) {
      uint256 claimAmount = claimCalculation(_balPoolId, _currentDate);
      shyftToken.safeTransferFrom(address(this), address(msg.sender), claimAmount.div(1e18));
    }
  }

  // Deposit Balancer LP token
  function deposit(
    uint256 _balPoolId, 
    uint256 _amount,
    uint256 _currentDate
  ) external {
    PoolData storage pool = poolData[_balPoolId];
    UserData storage user = userData[_balPoolId][msg.sender];

    if (user.lpAmount > 0 && user.lastClaimDate > 0) {
      uint256 claimAmount = claimCalculation(_balPoolId, _currentDate);
      shyftToken.safeTransferFrom(address(this), address(msg.sender), claimAmount.div(1e18));
    }
    
    user.lpAmount = user.lpAmount.add(_amount);
    user.lastClaimDate = _currentDate;
    pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);

    emit Deposited(msg.sender, _balPoolId, _amount);
  }

  // Withdraw Balancer LP token
  function withdraw(
    uint256 _balPoolId,
    uint256 _amount,
    uint256 _currentDate
  ) external {
    PoolData storage pool = poolData[_balPoolId];
    UserData storage user = userData[_balPoolId][msg.sender];
    require(user.lpAmount >= _amount, 'Insufficient amount');

    if (user.lpAmount > 0 && user.lastClaimDate > 0) {
      uint256 claimAmount = claimCalculation(_balPoolId, _currentDate);
      shyftToken.safeTransferFrom(address(this), address(msg.sender), claimAmount.div(1e18));
    }

    user.lpAmount = user.lpAmount.sub(_amount);
    user.lastClaimDate = _currentDate;
    pool.lpToken.safeTransferFrom(address(this), address(msg.sender), _amount);

    emit Withdrew(msg.sender, _balPoolId, _amount);
  }

  // Calculate the claim amount shyft
  function claimCalculation(
    uint256 _balPoolId,
    uint256 _currentDate
  ) private view returns (uint256 claimAmount) {
    PoolData storage pool = poolData[_balPoolId];
    UserData storage user = userData[_balPoolId][msg.sender];
    
    uint256 totalPoolLP = pool.lpToken.balanceOf(address(this));
    if (totalPoolLP != 0) {
      uint256 diffDate = _currentDate.sub(user.lastClaimDate);
      uint256 sharePerWeek = diffDate.div(secondsAWeek);
      claimAmount = pool.numShyftPerWeek.mul(user.lpAmount).mul(sharePerWeek).mul(1e18).div(totalPoolLP);
    }
  }

  // Get pools length
  function getPoolsLength() external view returns (uint256 poolsLength) {
    poolsLength = poolData.length;
  }

  // Get total pool lp for a specific balancer pool
  function getTotalPoolLP(
    uint256 _balPoolId
  ) external view returns (uint256 totalPoolLP) {
    PoolData storage pool = poolData[_balPoolId];
    totalPoolLP = pool.lpToken.balanceOf(address(this));
  }
}