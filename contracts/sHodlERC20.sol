// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.4;

import "./lib/Address.sol";
import "./lib/SafeMath.sol";

import "./types/ERC20Permit.sol";

import "./interfaces/IsBTCH.sol";
import "./interfaces/IStaking.sol";

contract sHodlERC20Token is IsBTCH, ERC20Permit {
    using SafeMath for uint256;

    event LogSupply(uint256 indexed epoch, uint256 totalSupply);
    event LogRebase(uint256 indexed epoch, uint256 rebase, uint256 index);
    event LogStakingContractUpdated(address stakingContract);

    modifier onlyStakingContract() {
        require(msg.sender == stakingContract, "NoStakingContract");
        _;
    }

    struct Rebase {
        uint256 epoch;
        uint256 rebase; //18 decimals
        uint256 totalStakedBefore;
        uint256 totalStakedAfter;
        uint256 amountRebased;
        uint256 index;
        uint256 blockNumberOccured;
    }

    address internal initializer;

    uint256 internal INDEX; // Index Gons - tracks rebase growth

    address public stakingContract; // balance used to calc rebase

    Rebase[] public rebases; // past rebase data

    uint256 private constant MAX_UINT256 = type(uint256).max;
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 5_000_000 * 10**9;

    // TOTAL_GONS is a multiple of INITIAL_FRAGMENTS_SUPPLY so that _gonsPerFragment is an integer.
    // Use the highest value that fits in a uint256 for max granularity.
    uint256 private constant TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

    // MAX_SUPPLY = maximum integer < (sqrt(4*TOTAL_GONS + 1) - 1) / 2
    uint256 private constant MAX_SUPPLY = ~uint128(0); // (2^128) - 1

    uint256 private _gonsPerFragment;
    mapping(address => uint256) private _gonBalances;

    mapping(address => mapping(address => uint256)) private _allowedValue;

    address public treasury;

    constructor() ERC20("Staked BTCH", "sBTCH", 9) ERC20Permit("Staked BTCH") 
    {
        initializer = msg.sender;
        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
    }

    function setIndex(uint256 _index) external 
    {
        require(msg.sender == initializer, "Initializer:  caller is not initializer");
        require(INDEX == 0, "Cannot set INDEX again");
        INDEX = gonsForBalance(_index);
    }

    // do this last
    function initialize(address _stakingContract, address _treasury) external 
    {
        require(msg.sender == initializer, "Initializer:  caller is not initializer");

        require(_stakingContract != address(0), "Staking");
        stakingContract = _stakingContract;
        _gonBalances[stakingContract] = TOTAL_GONS;

        require(_treasury != address(0), "Zero address: Treasury");
        treasury = _treasury;

        emit Transfer(address(0x0), stakingContract, _totalSupply);
        emit LogStakingContractUpdated(stakingContract);

        initializer = address(0);
    }

    //increases BTCH supply to increase staking balances relative to profit_
    function rebase(uint256 profit_, uint256 epoch_) public override onlyStakingContract returns (uint256) 
    {
        uint256 rebaseAmount;
        uint256 circulatingSupply_ = circulatingSupply();
        if (profit_ == 0) {
            emit LogSupply(epoch_, _totalSupply);
            emit LogRebase(epoch_, 0, index());
            
            //Need to store each rebase even no profit.
            _storeRebase(circulatingSupply_, profit_, epoch_);
            return _totalSupply;
        } 
        else if(circulatingSupply_ > 0) 
        {
            rebaseAmount = profit_.mul(_totalSupply).div(circulatingSupply_);
        } 
        else 
        {
            rebaseAmount = profit_;
        }

        _totalSupply = _totalSupply.add(rebaseAmount);

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);

        _storeRebase(circulatingSupply_, profit_, epoch_);

        return _totalSupply;
    }

    //emits event with data about rebase
    function _storeRebase(uint256 previousCirculating_, uint256 profit_, uint256 epoch_) internal 
    {
        uint256 rebasePercent = previousCirculating_ > 0 ? profit_.mul(1e18).div(previousCirculating_) : 0;
        rebases.push(
            Rebase({
                epoch: epoch_,
                rebase: rebasePercent, // 18 decimals
                totalStakedBefore: previousCirculating_,
                totalStakedAfter: circulatingSupply(),
                amountRebased: profit_,
                index: index(),
                blockNumberOccured: block.number
            })
        );

        emit LogSupply(epoch_, _totalSupply);
        emit LogRebase(epoch_, rebasePercent, index());
    }

    function transfer(address to, uint256 value) public override(IERC20, ERC20) returns (bool) 
    {
        uint256 gonValue = value.mul(_gonsPerFragment);

        _gonBalances[msg.sender] = _gonBalances[msg.sender].sub(gonValue);
        _gonBalances[to] = _gonBalances[to].add(gonValue);

        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public override(IERC20, ERC20) returns (bool) 
    {
        _allowedValue[from][msg.sender] = _allowedValue[from][msg.sender].sub(value);
        emit Approval(from, msg.sender, _allowedValue[from][msg.sender]);

        uint256 gonValue = gonsForBalance(value);
        _gonBalances[from] = _gonBalances[from].sub(gonValue);
        _gonBalances[to] = _gonBalances[to].add(gonValue);

        emit Transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public override(IERC20, ERC20) returns (bool) 
    {
        _approve(msg.sender, spender, value);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public override returns (bool) 
    {
        _approve(msg.sender, spender, _allowedValue[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public override returns (bool) 
    {
        uint256 oldValue = _allowedValue[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _approve(msg.sender, spender, 0);
        } else {
            _approve(msg.sender, spender, oldValue.sub(subtractedValue));
        }
        return true;
    }

    function _approve(address owner, address spender, uint256 value) internal virtual override 
    {
        _allowedValue[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function balanceOf(address who) public view override(IERC20, ERC20) returns (uint256) 
    {
        return _gonBalances[who].div(_gonsPerFragment);
    }

    function gonsForBalance(uint256 amount) public view override returns (uint256) 
    {
        return amount.mul(_gonsPerFragment);
    }

    function balanceForGons(uint256 gons) public view override returns (uint256) 
    {
        return gons.div(_gonsPerFragment);
    }
    
    function gonsForBalancePerEpoch(uint256 amountPerEpoch, uint256 fromEpoch, uint256 toEpoch) public view override returns (uint256) 
    {
        //Note: rebases[i].index indicates the index for rebases[i].epoch+1 actually.
        if(rebases.length == 0 || fromEpoch >= rebases[0].epoch + rebases.length || toEpoch < fromEpoch)
            return 0;
            
        require(fromEpoch >= rebases[0].epoch, "InvalidEpoch");
        if(toEpoch >= rebases[0].epoch + rebases.length)
            toEpoch = rebases[0].epoch + rebases.length - 1;

        uint retGons;
        uint startIndex;
        uint rangeLength;
        if(fromEpoch == rebases[0].epoch) {
            startIndex = 0;
            rangeLength = toEpoch - fromEpoch;
            retGons += amountPerEpoch.mul(INDEX.div(rebases[0].index));
        }
        else {
            startIndex = fromEpoch - rebases[0].epoch - 1;
            rangeLength = toEpoch - fromEpoch + 1;
        }
        for(uint i=0; i< rangeLength; i++) {
            retGons += amountPerEpoch.mul(INDEX.div(rebases[startIndex+i].index));
        }
        
        return retGons;
    }

    // Staking contract holds excess sBTCH
    function circulatingSupply() public view override returns (uint256) 
    {
        return _totalSupply.sub(balanceOf(stakingContract));
    }
    
    function index0() public view override returns (uint256) 
    {
        if(rebases.length == 0)
            return balanceForGons(INDEX);
        else
            return rebases[0].index;
    }

    function index() public view override returns (uint256) 
    {
        return balanceForGons(INDEX);
    }

    function allowance(address owner_, address spender) public view override(IERC20, ERC20) returns (uint256) 
    {
        return _allowedValue[owner_][spender];
    }
}
