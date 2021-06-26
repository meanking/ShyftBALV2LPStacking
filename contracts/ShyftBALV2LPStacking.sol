//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ShyftBALV2LPStacking is Ownable {
  using SafeERC20 for IERC20;
  using SafeMath  for uint256;

  struct PoolData {
    IERC20 lpToken;
    uint256 numShyftPerWeek;
  }

  struct UserData {
    uint256 lpAmount;
    uint256 claimReward;
  }

  IERC20 shyftToken; // Shyft token
  
  PoolData[] public poolData;
  mapping (uint256 => mapping (address => UserData)) public userData;

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
    uint256 _balPoolId
  ) public view returns (uint256 pendingAmount) {
    UserData storage user = userData[_balPoolId][msg.sender];
    if (user.lpAmount > 0) {
      pendingAmount = claimCalculation(_balPoolId);
    }
  }
  
  // Claim reward for a user
  function claim(
    uint256 _balPoolId
  ) external {
    UserData storage user = userData[_balPoolId][msg.sender];
    if (user.lpAmount > 0) {
      uint256 claimAmount = claimCalculation(_balPoolId);
      shyftToken.safeTransferFrom(address(this), address(msg.sender), claimAmount);
    }
  }

  // Deposit Balancer LP token
  function deposit(
    uint256 _balPoolId, 
    uint256 _amount
  ) external {
    PoolData storage pool = poolData[_balPoolId];
    UserData storage user = userData[_balPoolId][msg.sender];

    if (user.lpAmount > 0) {
      uint256 claimAmount = claimCalculation(_balPoolId);
      shyftToken.safeTransferFrom(address(this), address(msg.sender), claimAmount);
    }
    
    user.lpAmount = user.lpAmount.add(_amount);
    pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
  }

  // Withdraw Balancer LP token
  function withdraw(
    uint256 _balPoolId,
    uint256 _amount
  ) external {
    PoolData storage pool = poolData[_balPoolId];
    UserData storage user = userData[_balPoolId][msg.sender];
    require(user.lpAmount >= _amount, 'Insufficient amount');

    if (user.lpAmount > 0) {
      uint256 claimAmount = claimCalculation(_balPoolId);
      shyftToken.safeTransferFrom(address(this), address(msg.sender), claimAmount);
    }

    user.lpAmount = user.lpAmount.sub(_amount);
    pool.lpToken.safeTransferFrom(address(this), address(msg.sender), _amount);
  }

  // Calculate the claim amount shyft
  function claimCalculation(
    uint256 _balPoolId
  ) private view returns (uint256 claimAmount) {
    PoolData storage pool = poolData[_balPoolId];
    UserData storage user = userData[_balPoolId][msg.sender];
    
    uint256 totalPoolLP = pool.lpToken.balanceOf(address(this));
    if (totalPoolLP != 0) {
      claimAmount = pool.numShyftPerWeek.mul(user.lpAmount).mul(1e18).div(totalPoolLP);
    }
  }
}