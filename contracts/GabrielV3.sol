// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


/// @title Archangel Reward Staking Pool V3 (GabrielV3)
/// @notice Stake tokens to Earn Rewards.
contract GabrielV3 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    /* ========== STATE VARIABLES ========== */
    mapping(address => mapping(uint256 => bool)) public inPool;

    address public sharks;
    uint256 public sPercent;
    
    address public whales;
    uint256 public wPercent;
    
    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    /* ========== STRUCTS ========== */
    struct ConstructorArgs {
        uint256 sPercent;
        uint256 wPercent;
        address sharks;
        address whales;
    }
    
    struct ExtraArgs {
        IERC20Upgradeable stakeToken;
        uint256 openTime;
        uint256 waitPeriod;
        uint256 lockDuration;
        uint256 maxStake;
    }

    struct PoolInfo {
        bool canStake;
        bool canHarvest;
        IERC20Upgradeable stakeToken;
        uint256 compounded;
        uint256 lockDuration;
        uint256 lockTime;
        uint256 maxStake;
        uint256 NORT;
        uint256 openTime;
        uint256 staked;
        uint256 unlockTime;
        uint256 unstaked;        
        uint256 waitPeriod;
        address[] harvestList;
        address[] rewardTokens;
        address[] stakeList;
        uint256[] dynamicRewardsInPool;
        uint256[] staticRewardsInPool;
    }

    struct UserInfo {
        uint256 amount;
        bool harvested;
        uint256[] nonHarvestedRewards;
    }

    /* ========== EVENTS ========== */
    event Harvest(uint256 pid, address user, uint256 amount);
    event RateUpdated(uint256 sharks, uint256 whales);
    event Stake(uint256 pid, address user, uint256 amount);
    event Unstake(uint256 pid, address user, uint256 amount);

    /* ========== CONSTRUCTOR ========== */
    function initialize(
        ConstructorArgs memory constructorArgs,
        ExtraArgs memory extraArgs,
        uint256 _NORT,
        address[] memory _rewardTokens,
        uint256[] memory _staticRewardsInPool
    ) public initializer onlyProxy {
        sPercent = constructorArgs.sPercent;
        wPercent = constructorArgs.wPercent;
        sharks = constructorArgs.sharks;
        whales = constructorArgs.whales;
        __Ownable_init();
        __UUPSUpgradeable_init();
        createPool(extraArgs, _NORT, _rewardTokens, _staticRewardsInPool);
    }

    /* ========== WRITE FUNCTIONS ========== */

    function _changeNORT(uint256 _pid, uint256 _NORT) internal {
        PoolInfo storage pool = poolInfo[_pid];
        address[] memory rewardTokens = new address[](_NORT);
        uint256[] memory staticRewardsInPool = new uint256[](_NORT);
        pool.NORT = _NORT;
        pool.rewardTokens = rewardTokens;
        pool.dynamicRewardsInPool = staticRewardsInPool;
        pool.staticRewardsInPool = staticRewardsInPool;
    }

    function changeNORT(uint256 _pid, uint256 _NORT) external onlyOwner {
        _changeNORT(_pid, _NORT);
    }

    function changeRewardTokens(uint256 _pid, address[] memory _rewardTokens) external onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 NORT = pool.NORT;
        require(_rewardTokens.length == NORT, "CRT: array length mismatch");
        for (uint256 i; i < NORT; ++i) {
            pool.rewardTokens[i] = _rewardTokens[i];
        }
    }

    /**
     * @notice create a new pool
     * @param extraArgs ["stakeToken", openTime, waitPeriod, lockDuration]
     * @param _NORT specify the number of diffrent tokens the pool will give out as reward
     * @param _rewardTokens an array containing the addresses of the different reward tokens
     * @param _staticRewardsInPool an array of token balances for each unique reward token in the pool.
     */
    function createPool(ExtraArgs memory extraArgs, uint256 _NORT, address[] memory _rewardTokens, uint256[] memory _staticRewardsInPool) public onlyOwner {
        require(_rewardTokens.length == _NORT && _rewardTokens.length == _staticRewardsInPool.length, "CP: array length mismatch");
        address[] memory rewardTokens = new address[](_NORT);
        uint256[] memory staticRewardsInPool = new uint256[](_NORT);
        address[] memory emptyList;
        require(
            extraArgs.openTime > block.timestamp,
            "open time must be a future time"
        );
        uint256 _lockTime = extraArgs.openTime.add(extraArgs.waitPeriod);
        uint256 _unlockTime = _lockTime.add(extraArgs.lockDuration);
        
        poolInfo.push(
            PoolInfo({
                stakeToken: extraArgs.stakeToken,
                staked: 0,
                maxStake: extraArgs.maxStake,
                compounded: 0,
                unstaked: 0,
                openTime: extraArgs.openTime,
                waitPeriod: extraArgs.waitPeriod,
                lockTime: _lockTime,
                lockDuration: extraArgs.lockDuration,
                unlockTime: _unlockTime,
                canStake: false,
                canHarvest: false,
                NORT: _NORT,
                rewardTokens: rewardTokens,
                dynamicRewardsInPool: staticRewardsInPool,
                staticRewardsInPool: staticRewardsInPool,
                stakeList: emptyList,
                harvestList: emptyList
            })
        );
        uint256 _pid = poolInfo.length - 1;
        PoolInfo storage pool = poolInfo[_pid];
        for (uint256 i; i < _NORT; ++i) {
            pool.rewardTokens[i] = _rewardTokens[i];
            pool.dynamicRewardsInPool[i] = _staticRewardsInPool[i];
            pool.staticRewardsInPool[i] = _staticRewardsInPool[i];
        }
    }

    /**
     * @notice Add your earnings to your stake
     * @dev compounding should be done after harvesting
     * @param _pid select the particular pool
    */
    function compoundArcha(uint256 _pid, address userAddress, bool leaveRewards) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][userAddress];
        uint256 NORT = pool.NORT;
        uint256 arrayLength = user.nonHarvestedRewards.length;
        uint256 pending;
        if (!leaveRewards) {
            uint256 reward = user.amount * pool.staticRewardsInPool[0];
            uint256 lpSupply = pool.staked;
            pending = reward.div(lpSupply);
        }
        if (arrayLength == 0) {
            uint256 reward = user.amount * pool.staticRewardsInPool[0];
            uint256 lpSupply = pool.staked;
            pending = reward.div(lpSupply);
            uint256 futureStake = pending.add(user.amount);
            if (futureStake > pool.maxStake) {
                uint256 toMax = pool.maxStake.sub(user.amount);
                uint256 excess = pending.sub(toMax);
                pending = toMax;
                user.nonHarvestedRewards = new uint256[](NORT);
                user.nonHarvestedRewards[0] = excess;
            }    
        }
        if (arrayLength == NORT) {
            uint256 newPending = pending.add(user.nonHarvestedRewards[0]);
            uint256 futureStake = newPending.add(user.amount);
            if (futureStake <= pool.maxStake) {
                pending = pending.add(user.nonHarvestedRewards[0]);
                user.nonHarvestedRewards[0] = 0;
            } else if (futureStake > pool.maxStake) {
                user.nonHarvestedRewards[0] = user.nonHarvestedRewards[0].add(pending);
                uint256 toMax = pool.maxStake.sub(user.amount);
                pending = toMax;
                user.nonHarvestedRewards[0] = user.nonHarvestedRewards[0].sub(toMax);
            }    
        }
        if (pending > 0) {
            pool.compounded = pool.compounded.add(pending);
            require(pending.add(user.amount) <= pool.maxStake, "you cannot stake more than the maximum");
            (bool inAnotherPool, uint256 pid) = checkIfAlreadyInAPool(userAddress);
            if (inAnotherPool) {
                require(pid == _pid, "staking in more than one pool is forbidden");
            }
            bool alreadyInAPool = inPool[userAddress][_pid];
            if (!alreadyInAPool) {
                inPool[userAddress][_pid] = true;
            }
            user.amount = user.amount.add(pending);
            emit Stake(_pid, userAddress, pending);
        }
    }

    /**
     * @notice Harvest your earnings
     * @param _pid select the particular pool
     * @param leaveRewards decide if you want to leave rewards in the pool till next round
    */
    function harvest(uint256 _pid, bool compound, bool leaveRewards) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (block.timestamp > pool.unlockTime && !(pool.canHarvest)) {
            pool.canHarvest = true;
        }
        require(pool.canHarvest, "pool is still locked");
        require(!(user.harvested), "Harvest: you have already claimed rewards for this round");
        pool.harvestList.push(msg.sender);
        update(_pid);
        uint256 NORT = pool.NORT;
        uint256 arrayLength = user.nonHarvestedRewards.length;
        if (arrayLength < NORT && arrayLength > 0) {
            uint256 increaseBy = NORT.sub(arrayLength);
            for (uint256 i; i < increaseBy; ++i) {
                user.nonHarvestedRewards.push(0);
            }
            arrayLength = user.nonHarvestedRewards.length;
        }
        user.harvested = true;
        if (compound && leaveRewards) {
            storeUnclaimedRewards(_pid, msg.sender);
            compoundArcha(_pid, msg.sender, leaveRewards);
        } else if (compound && !leaveRewards) {
            for (uint256 i; i < NORT; ++i) {
                if (i == 0) { continue; }
                uint256 reward = user.amount * pool.staticRewardsInPool[i];
                uint256 lpSupply = pool.staked;
                uint256 pending = reward.div(lpSupply);
                pool.dynamicRewardsInPool[i] = pool.dynamicRewardsInPool[i].sub(pending);
                if (arrayLength == NORT) {
                    pending = pending.add(user.nonHarvestedRewards[i]);
                    user.nonHarvestedRewards[i] = 0; 
                }
                if (pending > 0) {
                    emit Harvest(_pid, msg.sender, pending);
                    IERC20Upgradeable(pool.rewardTokens[i]).safeTransfer(msg.sender, pending);
                }
            }
            compoundArcha(_pid, msg.sender, leaveRewards);
        } else if (!compound && leaveRewards) {
            storeUnclaimedRewards(_pid, msg.sender);
        } else if (!compound && !leaveRewards) {
            for (uint256 i; i < NORT; ++i) {
                uint256 reward = user.amount * pool.staticRewardsInPool[i];
                uint256 lpSupply = pool.staked;
                uint256 pending = reward.div(lpSupply);
                pool.dynamicRewardsInPool[i] = pool.dynamicRewardsInPool[i].sub(pending);
                if (arrayLength == NORT) {
                    pending = pending.add(user.nonHarvestedRewards[i]);
                    user.nonHarvestedRewards[i] = 0; 
                }
                if (pending > 0) {
                    emit Harvest(_pid, msg.sender, pending);
                    IERC20Upgradeable(pool.rewardTokens[i]).safeTransfer(msg.sender, pending);
                }
            }
        }
    }

    /**
     * @notice prepare a pool for the next round of staking
     * @param _pid select the particular pool
     * @param extraArgs ["stakeToken", openTime, waitPeriod, lockDuration]
     * @param _NORT specify the number of diffrent tokens the pool will give out as reward
     * @param _rewardTokens an array containing the addresses of the different reward tokens
     * @param _staticRewardsInPool an array of token balances for each unique reward token in the pool.
     */
    function nextRound(uint256 _pid, ExtraArgs memory extraArgs, uint256 _NORT, address[] memory _rewardTokens, uint256[] memory _staticRewardsInPool) external onlyOwner {
        require(
            _rewardTokens.length == _NORT &&
            _rewardTokens.length == _staticRewardsInPool.length,
            "RP: array length mismatch"
        );
        PoolInfo storage pool = poolInfo[_pid];
        pool.stakeToken = extraArgs.stakeToken;
        pool.maxStake = extraArgs.maxStake;
        pool.staked = pool.staked.add(pool.compounded);
        pool.staked = pool.staked.sub(pool.unstaked);
        pool.compounded = 0;
        pool.unstaked = 0;
        _setTimeValues( _pid, extraArgs.openTime, extraArgs.waitPeriod, extraArgs.lockDuration);
        _changeNORT(_pid, _NORT);
        for (uint256 i; i < _NORT; ++i) {
            pool.rewardTokens[i] = _rewardTokens[i];
            pool.dynamicRewardsInPool[i] = _staticRewardsInPool[i];
            pool.staticRewardsInPool[i] = _staticRewardsInPool[i];
        }
    }

    /// @notice allows for sending back locked tokens
    function recoverERC20(address token, address recipient, uint256 amount) external onlyOwner {
        IERC20Upgradeable(token).safeTransfer(recipient, amount);
    }

    /**
     * @notice sets user.harvested to false for all users
     * @dev the startIndex and endIndex are used to split the tnx into smaller batches
     * @param _pid select the particular pool
     * @param startIndex is the starting point for this batch.
     * @param endIndex is the ending point for this batch.
     */
    function reset(uint256 _pid, uint256 startIndex, uint256 endIndex) external onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 arrayLength = pool.harvestList.length;
        for (uint256 i = startIndex; i < endIndex; ++i) {
            UserInfo storage user = userInfo[_pid][pool.harvestList[i]];
            user.harvested = false;
        }

        address lastArgAddr = pool.harvestList[endIndex - 1];
        address lastHarvester = pool.harvestList[arrayLength - 1];
        if (lastHarvester == lastArgAddr) {
            address[] memory emptyList;
            pool.harvestList = emptyList;
        }
    }

    function setPoolReward(uint256 _pid, address token, uint256 amount) external onlyOwner {
        uint256 onePercent = amount.div(100);
        uint256 tShare = wPercent.mul(onePercent);
        uint256 mShare = amount.sub(tShare);
        emit RateUpdated(_pid, amount);
        IERC20Upgradeable(token).safeTransfer(sharks, mShare);
        IERC20Upgradeable(token).safeTransfer(whales, tShare);
    }

    /**
     * @notice Set or modify the token balances of a particular pool
     * @param _pid select the particular pool
     * @param rewards array of token balances for each reward token in the pool
     */
    function setPoolRewards(uint256 _pid, uint256[] memory rewards) external onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 NORT = pool.NORT;
        require(rewards.length == NORT, "SPR: array length mismatch");
        for (uint256 i; i < NORT; ++i) {
            pool.dynamicRewardsInPool[i] = rewards[i];
            pool.staticRewardsInPool[i] = rewards[i];
        }
    }

    // function setRates(uint256 _sPercent, uint256 _wPercent) external onlyOwner {
    //     require(_sPercent.add(_wPercent) == 100, "must sum up to 100%");
    //     sPercent = _sPercent;
    //     wPercent = _wPercent;
    //     emit RateUpdated(_sPercent, _wPercent);
    // }

    function setSharkPoolAddress(address _sharks) external {
        require(msg.sender == sharks, "sharks: caller is not the current sharks");
        require(_sharks != address(0), "cannot set sharks as zero address");
        sharks = _sharks;
    }

    function _setTimeValues(
        uint256 _pid,
        uint256 _openTime,
        uint256 _waitPeriod,
        uint256 _lockDuration
    ) internal {
        PoolInfo storage pool = poolInfo[_pid];
        require(
            _openTime > block.timestamp,
            "open time must be a future time"
        );
        pool.openTime = _openTime;
        pool.waitPeriod = _waitPeriod;
        pool.lockTime = _openTime.add(_waitPeriod);
        pool.lockDuration = _lockDuration;
        pool.unlockTime = pool.lockTime.add(_lockDuration);
    }

    function setTimeValues(
        uint256 _pid,
        uint256 _openTime,
        uint256 _waitPeriod,
        uint256 _lockDuration
    ) external onlyOwner {
        _setTimeValues(_pid, _openTime, _waitPeriod, _lockDuration);
    }

    /// @notice Update whales address.
    function setWhalePoolAddress(address _whales) external onlyOwner {
        require(_whales != address(0), "cannot set whales as zero address");
        whales = _whales;
    }

    /**
     * @notice stake ERC20 tokens to earn rewards
     * @param _pid select the particular pool
     * @param _amount amount of tokens to be deposited by user
     */
    function stake(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (block.timestamp > pool.lockTime && pool.canStake) {
            pool.canStake = false;
        }
        if (
            block.timestamp > pool.openTime &&
            block.timestamp < pool.lockTime &&
            block.timestamp < pool.unlockTime &&
            !(pool.canStake)
        ) {
            pool.canStake = true;
        }
        require(
            pool.canStake,
            "pool is not yet opened or is locked"
        );
        require(_amount > 0, "you cannot stake a value less than 1");
        require(_amount.add(user.amount) <= pool.maxStake, "you cannot stake more than the maximum");
        (bool inAnotherPool, uint256 pid) = checkIfAlreadyInAPool(msg.sender);
        if (inAnotherPool) {
            require(
                pid == _pid,
                "staking in more than one pool isn't allowed"
            );
        }
        bool alreadyInAPool = inPool[msg.sender][_pid];
        if (!alreadyInAPool) {
            inPool[msg.sender][_pid] = true;
        }
        update(_pid);
        pool.stakeList.push(msg.sender);
        user.amount = user.amount.add(_amount);
        pool.staked = pool.staked.add(_amount);
        emit Stake(_pid, msg.sender, _amount);
        pool.stakeToken.safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
    }

    function storeUnclaimedRewards(uint256 _pid, address userAddress) internal {
        PoolInfo memory pool = poolInfo[_pid];
        uint256 NORT = pool.NORT;
        UserInfo storage user = userInfo[_pid][userAddress];
        uint256 arrayLength = user.nonHarvestedRewards.length;
        if (arrayLength == 0) {
            user.nonHarvestedRewards = new uint256[](NORT);
            for (uint256 x = 0; x < NORT; ++x) {
                uint256 reward = user.amount * pool.staticRewardsInPool[x];
                uint256 lpSupply = pool.staked;
                uint256 pending = reward.div(lpSupply);
                if (pending > 0) {
                    user.nonHarvestedRewards[x] = pending;
                }
            }
        }
        if (arrayLength == NORT) {
            for (uint256 x = 0; x < NORT; ++x) {
                uint256 reward = user.amount * pool.staticRewardsInPool[x];
                uint256 lpSupply = pool.staked;
                uint256 pending = reward.div(lpSupply);
                if (pending > 0) {
                    user.nonHarvestedRewards[x] = user.nonHarvestedRewards[x].add(pending);
                }
            }
        }
    }

    /**
     * @notice Exit without caring about rewards
     * @param _pid select the particular pool
    */
    function unstake(uint256 _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount > 0, "unstake: your staked balance is zero");
        bool alreadyInAPool = inPool[msg.sender][_pid];
        if (alreadyInAPool) {
            inPool[msg.sender][_pid] = false;
        }
        pool.unstaked = pool.unstaked.add(user.amount);
        uint256 staked = user.amount;
        user.amount = 0;
        emit Unstake(_pid, msg.sender, staked);
        pool.stakeToken.safeTransfer(msg.sender, staked);
    }

    function update(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.openTime) {
            return;
        }
        if (
            block.timestamp > pool.openTime &&
            block.timestamp < pool.lockTime &&
            block.timestamp < pool.unlockTime
        ) {
            pool.canStake = true;
            pool.canHarvest = false;
        }
        if (
            block.timestamp > pool.lockTime &&
            block.timestamp < pool.unlockTime
        ) {
            pool.canStake = false;
            pool.canHarvest = false;
        }
        if (
            block.timestamp > pool.unlockTime &&
            pool.unlockTime > 0
        ) {
            pool.canStake = false;
            pool.canHarvest = true;
        }
    }

    function _authorizeUpgrade(address newImplementation) internal onlyOwner override {
        // solhint-disable-previous-line no-empty-blocks
    }

    /* ========== READ ONLY FUNCTIONS ========== */

    // will return default values (false, 0) if !(alreadyInAPool)
    function checkIfAlreadyInAPool(address user) internal view returns (bool inAnotherPool, uint256 pid) {
        for (uint256 poolId; poolId < poolInfo.length; ++poolId) {
            if (poolInfo.length > 0) {
                bool alreadyInAPool = inPool[user][poolId];
                if (alreadyInAPool) {
                    return (alreadyInAPool, poolId);
                }
            }
        }
    }

    function dynamicRewardInPool(uint256 _pid) external view returns (uint256[] memory dynamicRewardsInPool) {
        PoolInfo memory pool = poolInfo[_pid];
        dynamicRewardsInPool = pool.dynamicRewardsInPool;
    }

    // function harvesters(uint256 _pid) external view returns (address[] memory) {
    //     PoolInfo memory pool = poolInfo[_pid];
    //     return pool.harvestList;
    // }

    function harvests(uint256 _pid) external view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        return pool.harvestList.length;
    }

    function isInArray(address[] memory array, address item) internal pure returns (bool) {
        for (uint256 i; i < array.length; ++i) {
            if (array[i] == item) {
                return true;
            }
        }
        return false;
    }

    function nonHarvestedRewards(uint256 _pid, address staker) external view returns (uint256[] memory) {
        UserInfo memory user = userInfo[_pid][staker];
        return user.nonHarvestedRewards;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function stakers(uint256 _pid) external view returns (address[] memory) {
        PoolInfo memory pool = poolInfo[_pid];
        return pool.stakeList;
    }

    function stakes(uint256 _pid) external view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        if (pool.stakeList.length > 0) {
            uint256 counter = 1;
            uint256 index = counter - 1;
            address[] memory newArray = new address[](counter);
            newArray[index] = pool.stakeList[index];
            for (uint256 i; i < pool.stakeList.length; ++i) {
                if (!(isInArray(newArray, pool.stakeList[i]))) {
                    counter += 1;
                    index = counter - 1;
                    address[] memory oldArray = newArray;
                    newArray = new address[](counter);
                    for (uint256 x; x < oldArray.length; ++x) {
                        newArray[x] = oldArray[x];
                    }
                    newArray[index] = pool.stakeList[i];
                }
            }
            return newArray.length;
        } else {
            return 0;
        }
    }

    function staticRewardInPool(uint256 _pid) external view returns (uint256[] memory staticRewardsInPool) {
        PoolInfo memory pool = poolInfo[_pid];
        staticRewardsInPool = pool.staticRewardsInPool;
    }

    function tokensInPool(uint256 _pid) external view returns (address[] memory rewardTokens) {
        PoolInfo memory pool = poolInfo[_pid];
        rewardTokens = pool.rewardTokens;
    }

    function unclaimedRewards(uint256 _pid, address _user)
        external
        view
        returns (uint256[] memory unclaimedReward)
    {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 NORT = pool.NORT;
        uint256 arrayLength = user.nonHarvestedRewards.length;
        uint256[] memory notHarvested = new uint256[](NORT);
        bool useMem;
        if (arrayLength < NORT && arrayLength > 0) {
            for (uint256 i; i < NORT; ++i) {
                if (i < arrayLength) {
                    notHarvested[i] = user.nonHarvestedRewards[i];
                } else {
                    notHarvested[i] = 0;
                }
            }
            arrayLength = notHarvested.length;
            useMem = true;
        }
        if (block.timestamp > pool.lockTime && block.timestamp < pool.unlockTime && !(user.harvested) && pool.staked != 0) {
            uint256[] memory array = new uint256[](NORT);
            for (uint256 i; i < NORT; ++i) {
                uint256 blocks = block.timestamp.sub(pool.lockTime);
                uint256 reward = blocks * user.amount * pool.staticRewardsInPool[i];
                uint256 lpSupply = pool.staked * pool.lockDuration;
                uint256 pending = reward.div(lpSupply);
                if (arrayLength == NORT) {
                    if (useMem) {
                        pending = pending.add(notHarvested[i]);
                    } else {
                        pending = pending.add(user.nonHarvestedRewards[i]);
                    }
                }
                array[i] = pending;
            }
            return array;
        } else if (block.timestamp > pool.unlockTime && !(user.harvested) && pool.staked != 0) {
            uint256[] memory array = new uint256[](NORT);
            for (uint256 i; i < NORT; ++i) {                
                uint256 reward = user.amount * pool.staticRewardsInPool[i];
                uint256 lpSupply = pool.staked;
                uint256 pending = reward.div(lpSupply);
                if (arrayLength == NORT) {
                    if (useMem) {
                        pending = pending.add(notHarvested[i]);
                    } else {
                        pending = pending.add(user.nonHarvestedRewards[i]);
                    }
                }
                array[i] = pending;
            }
            return array;
        } else {
            uint256[] memory array = new uint256[](NORT);
            for (uint256 i; i < NORT; ++i) {
                uint256 pending = 0;
                if (arrayLength == NORT) {
                    if (useMem) {
                        pending = notHarvested[i];
                    } else {
                        pending = user.nonHarvestedRewards[i];
                    }
                }                
                array[i] = pending;
            }
            return array;
        }        
    }
}