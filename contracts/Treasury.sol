// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

import "./lib/SafeMath.sol";
import "./lib/SafeERC20.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/IBTCH.sol";
import "./interfaces/IsBTCH.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IRebalancer.sol";

import "./types/HodlAccessControlled.sol";

contract HodlTreasury is HodlAccessControlled, ITreasury {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event Deposit(address indexed token, uint256 amount, uint256 value);
    event Withdrawal(address indexed token, uint256 amount);
    event Managed(address indexed token, uint256 amount);
    event Minted(address indexed caller, address indexed recipient, uint256 amount);
    event PermissionQueued(STATUS indexed status, address queued);
    event Permissioned(address addr, STATUS indexed status, bool result);

    enum STATUS {
        RESERVEDEPOSITOR,   //0
        RESERVESPENDER,     //1
        RESERVETOKEN,       //2
        RESERVEMANAGER,     //3
        LIQUIDITYDEPOSITOR, //4
        LIQUIDITYTOKEN,     //5
        LIQUIDITYMANAGER,   //6
        REWARDMANAGER,      //7
        SBTCH,              //8
        REBALANCER          //9
    }

    struct Queue {
        STATUS managing;
        address toPermit;
        uint256 timelockEnd;
        bool nullify;
        bool executed;
    }

    IBTCH public immutable BTCH;
    IsBTCH public sBTCH;
    IRebalancer public rebalancer;

    mapping(STATUS => address[]) public registry;
    mapping(STATUS => mapping(address => bool)) public permissions;
    
    bool public timelockEnabled;
    uint256 public periodNeededForQueue = 3600*24; //1-day lock
    uint256 public onChainGovernanceTimelock;
    Queue[] public permissionQueue;

    string internal notAccepted = "TreasuryNotAccepted";
    string internal notApproved = "TreasuryNotApproved";
    string internal invalidToken = "TreasuryInvalidToken";

    constructor(
        address _btch,
        address _authority
    ) HodlAccessControlled(IHodlAuthority(_authority)) {
        require(_btch != address(0), "NoZeroAddress:BTCH");
        BTCH = IBTCH(_btch);
    }

    //allow approved address to deposit an asset for BTCH
    function deposit(uint256 _amount, address _token, uint256 _btchAmount) external override returns (uint256 send_) 
    {
        if(permissions[STATUS.RESERVETOKEN][_token]) {
            require(permissions[STATUS.RESERVEDEPOSITOR][msg.sender], notApproved);
        }
        else if(permissions[STATUS.LIQUIDITYTOKEN][_token]) {
            require(permissions[STATUS.LIQUIDITYDEPOSITOR][msg.sender], notApproved);
        }
        else {
            revert(invalidToken);
        }

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        send_ = _btchAmount;
        BTCH.mint(msg.sender, _btchAmount);
        emit Deposit(_token, _amount, _btchAmount);
    }

    //allow approved address to withdraw reserves for handling
    function withdraw(uint256 _amount, address _token) external override 
    {
        require(permissions[STATUS.RESERVETOKEN][_token], notAccepted);
        require(permissions[STATUS.RESERVESPENDER][msg.sender], notApproved);

        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit Withdrawal(_token, _amount);
    }

    //allow approved address to withdraw assets
    function manage(address _token, uint256 _amount) external override 
    {
        if (permissions[STATUS.LIQUIDITYTOKEN][_token]) {
            require(permissions[STATUS.LIQUIDITYMANAGER][msg.sender], notApproved);
        } else {
            require(permissions[STATUS.RESERVEMANAGER][msg.sender], notApproved);
        }

        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit Managed(_token, _amount);
    }

    //allow approved address to mint new BTCH
    function mint(address _recipient, uint256 _amount) external override 
    {
        require(permissions[STATUS.REWARDMANAGER][msg.sender], notApproved);
        BTCH.mint(_recipient, _amount);
        emit Minted(msg.sender, _recipient, _amount);
    }

    //enable permission from queue
    function enable(STATUS _status, address _address) external onlyGovernorPolicy 
    {
        require(timelockEnabled == false, "UseTimelock");
        if (_status == STATUS.SBTCH) {
            sBTCH = IsBTCH(_address);
        }
        else if (_status == STATUS.REBALANCER) {
            rebalancer = IRebalancer(_address);
        } 
        else {
            permissions[_status][_address] = true;
            (bool reg, ) = indexInRegistry(_address, _status);
            if(!reg) {
                registry[_status].push(_address);
            }
        }
        emit Permissioned(_address, _status, true);
    }

    //disable permission from address
    function disable(STATUS _status, address _toDisable) external 
    {
        require(msg.sender == authority.governor() || msg.sender == authority.guardian(), "OnlyGovernorOrGuardian");
        permissions[_status][_toDisable] = false;
        
        (bool reg, uint256 index) = indexInRegistry(_toDisable, _status);
        if(reg) {
            delete registry[_status][index];
        }
        emit Permissioned(_toDisable, _status, false);
    }

    //check if registry contains address
    function indexInRegistry(address _address, STATUS _status) public view returns (bool, uint256) 
    {
        address[] memory entries = registry[_status];
        for (uint256 i = 0; i < entries.length; i++) {
            if (_address == entries[i]) {
                return (true, i);
            }
        }
        return (false, 0);
    }
    
    function hodlValue() public view override returns (uint256) {
        return rebalancer.getWBTC2USDCValue();
    }
    
    //Enable timelocked
    function enableTimelock() external onlyGovernor 
    {
        require(timelockEnabled == false, "TimelockEnabled");
        
        timelockEnabled = true;
        onChainGovernanceTimelock = 0;
    }
    
    //disables timelocked
    function disableTimelock() external onlyGovernor 
    {
        require(timelockEnabled == true, "TimelockDisabled");
        
        if (onChainGovernanceTimelock != 0 && block.timestamp > onChainGovernanceTimelock) {
            timelockEnabled = false;
        } else {
            onChainGovernanceTimelock = block.timestamp.add(periodNeededForQueue.mul(7)); // 7-day timelock delay
        }
    }

    //queue address to receive permission
    function queueTimelock(STATUS _status, address _address) external onlyGovernor 
    {
        require(_address != address(0));
        require(timelockEnabled == true, "TimelockDisabled");

        uint256 timelock = block.timestamp.add(periodNeededForQueue.mul(3)); // 3-day timelock
        permissionQueue.push(
            Queue({
                managing: _status,
                toPermit: _address,
                timelockEnd: timelock,
                nullify: false,
                executed: false
            })
        );
        emit PermissionQueued(_status, _address);
    }

    //enable queued permission
    function execute(uint256 _index) external 
    {
        require(timelockEnabled == true, "TimelockDisabled");

        Queue memory info = permissionQueue[_index];

        require(!info.nullify, "ActionNullified");
        require(!info.executed, "ActionExecuted");
        require(block.timestamp >= info.timelockEnd, "TimelockOngoing");

        if(info.managing == STATUS.SBTCH) {
            sBTCH = IsBTCH(info.toPermit);
        }
        else if(info.managing == STATUS.REBALANCER) {
            rebalancer = IRebalancer(info.toPermit);
        }
        else {
            permissions[info.managing][info.toPermit] = true;

            (bool reg, ) = indexInRegistry(info.toPermit, info.managing);
            if (!reg) {
                registry[info.managing].push(info.toPermit);
            }
        }
        permissionQueue[_index].executed = true;
        emit Permissioned(info.toPermit, info.managing, true);
    }

    //cancel timelocked action
    function nullify(uint256 _index) external onlyGovernor 
    {
        permissionQueue[_index].nullify = true;
    }
}
