// File: contracts/modules/SafeMath.sol

pragma solidity ^0.8.4;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// File: contracts/modules/IERC20.sol
/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
 */
interface IERC20 {

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// File: contracts/modules/ReentrancyGuard.sol

contract ReentrancyGuard {

  /**
   * @dev We use a single lock for the whole contract.
   */
  bool private reentrancyLock = false;
  /**
   * @dev Prevents a contract from calling itself, directly or indirectly.
   * @notice If you mark a function `nonReentrant`, you should also
   * mark it `external`. Calling one nonReentrant function from
   * another is not supported. Instead, you can implement a
   * `private` function doing the actual work, and a `external`
   * wrapper marked as `nonReentrant`.
   */
  modifier nonReentrant() {
    require(!reentrancyLock);
    reentrancyLock = true;
    _;
    reentrancyLock = false;
  }

}

// File: contracts/modules/Ownable.sol

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable {
    address internal _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// File: contracts/modules/Halt.sol

contract Halt is Ownable {
    
    bool private halted = false; 
    
    modifier notHalted() {
        require(!halted,"This contract is halted");
        _;
    }

    modifier isHalted() {
        require(halted,"This contract is not halted");
        _;
    }
    
    /// @notice function Emergency situation that requires 
    /// @notice contribution period to stop or not.
    function setHalt(bool halt) 
        public 
        onlyOwner
    {
        halted = halt;
    }
}

// File: contracts/pregenesis/PreGenesisData.sol

contract PreGenesisData is ReentrancyGuard {

    //Special decimals for calculation
    uint256 constant internal rayDecimals = 1e27;

    uint256 constant internal InterestDecimals = 1e36;

    uint256 public totalAssetAmount;
    // Maximum amount of debt that can be generated with this collateral type
    uint256 public assetCeiling;       // [rad]
    // Minimum amount of debt that must be generated by a SAFE using this collateral
    uint256 public assetFloor;         // [rad]
    //interest rate
    uint256 internal interestRate;
    uint256 internal interestInterval;
    struct assetInfo{
        uint256 originAsset;
        uint256 baseAsset;
        uint256 finalAsset;//only used to record transfered vcoind amount
    }
    // debt balance
    mapping(address=>assetInfo) public assetInfoMap;

    // latest time to settlement
    uint256 internal latestSettleTime;
    uint256 internal accumulatedRate;

    bool public allowWithdraw;
    bool public allowDeposit;
    uint256 public maxRate = 200e27;
    uint256 public minRate = rayDecimals;
    address public coin;
    address public targetSc;

    bool public halted = false;
    modifier notHalted() {
        require(!halted,"This contract is halted");
        _;
    }

    modifier isHalted() {
        require(halted,"This contract is not halted");
        _;
    }



    event SetInterestInfo(address indexed from,uint256 _interestRate,uint256 _interestInterval);
    event AddAsset(address indexed recieptor,uint256 amount);
    event SubAsset(address indexed account,uint256 amount,uint256 subOrigin);

    event InitContract(address indexed sender,uint256 interestRate,uint256 interestInterval,
        uint256 assetCeiling,uint256 assetFloor);
    event Deposit(address indexed sender, address indexed account, uint256 amount);
    event Withdraw(address indexed sender, address indexed account, uint256 amount);
    event TransferToTarget(address indexed sender, address indexed account, uint256 amount);
    event TransferVCoinToTarget(address indexed sender, address indexed account, uint256 amount);
}


contract PreGenesisWithSafe is PreGenesisData{
    using SafeMath for uint256;

    address public safeMulsig;

    modifier onlyOrigin() {
        require(msg.sender==safeMulsig, "not setting safe contract");
        _;
    }

    constructor (address _safeMulsig)
    {
        safeMulsig = _safeMulsig;
        allowWithdraw = false;
        allowDeposit = false;
    }

    function initContract(uint256 _interestRate,uint256 _interestInterval,
        uint256 _assetCeiling,uint256 _assetFloor,address _coin,address _targetSc) external onlyOrigin{

        assetCeiling = _assetCeiling;
        assetFloor = _assetFloor;
        _setInterestInfo(_interestRate,_interestInterval,maxRate,rayDecimals);

        coin = _coin;
        targetSc = _targetSc;

        emit InitContract(msg.sender,_interestRate,_interestInterval,_assetCeiling,_assetFloor);
    }

    function setCoinAndTarget(address _coin,address _targetSc) public onlyOrigin {
        coin = _coin;
        targetSc = _targetSc;
    }

    function setPoolLimitation(uint256 _assetCeiling,uint256 _assetFloor) external onlyOrigin{
        assetCeiling = _assetCeiling;
        assetFloor = _assetFloor;
    }

    function setInterestInfo(uint256 _interestRate,uint256 _interestInterval)external onlyOrigin{
        _setInterestInfo(_interestRate,_interestInterval,maxRate,rayDecimals);
    }

    function setWithdrawStatus(bool _enable)external onlyOrigin{
       allowWithdraw = _enable;
    }

    function setDepositStatus(bool _enable)external onlyOrigin{
        allowDeposit = _enable;
    }

    function resetSafeMulsig(address _safeMulsig)external onlyOrigin{
        safeMulsig = _safeMulsig;
    }
    /// @notice function Emergency situation that requires
    /// @notice contribution period to stop or not.
    function setHalt(bool halt)
        public
        onlyOrigin
    {
        halted = halt;
    }

    function deposit(uint256 amount)
        notHalted
        nonReentrant
        external
    {
        require(allowDeposit,"deposit is not allowed!");
        require(totalAssetAmount < assetCeiling, "asset is overflow");

        if(totalAssetAmount.add(amount)>assetCeiling) {
            amount = assetCeiling.sub(totalAssetAmount);
        }
        IERC20(coin).transferFrom(msg.sender, address(this), amount);

        _interestSettlement();

        //user current vcoin amount + coin amount
        uint256 newAmount =  calBaseAmount(amount,accumulatedRate);
        assetInfoMap[msg.sender].baseAsset = assetInfoMap[msg.sender].baseAsset.add(newAmount);

        assetInfoMap[msg.sender].originAsset = assetInfoMap[msg.sender].originAsset.add(amount);
        totalAssetAmount = totalAssetAmount.add(amount);

        emit Deposit(msg.sender,msg.sender,amount);
    }

    function transferVCoin(address _user,uint256 _vCoinAmount)
        notHalted
        nonReentrant
        external
        returns(uint256)
    {
        require(msg.sender==targetSc,"wrong sender");

        _interestSettlement();

        uint256 assetAndInterest = getAssetBalance(_user);
        uint256 burnAmount = 0;

        if(assetAndInterest <= _vCoinAmount){
            //transfer user max baseAsset to targetSc
            burnAmount = assetInfoMap[_user].baseAsset;
            //final asset is assetAndInterest
            _vCoinAmount = assetAndInterest;
            //set baseAsset to 0
            assetInfoMap[_user].baseAsset = 0;
        }else if(assetAndInterest > _vCoinAmount){
            burnAmount = calBaseAmount(_vCoinAmount,accumulatedRate);
            assetInfoMap[_user].baseAsset = assetInfoMap[_user].baseAsset.sub(burnAmount);
        }

        //tartget sc only record vcoin balance,no interest
        assetInfoMap[targetSc].baseAsset = assetInfoMap[targetSc].baseAsset.add(burnAmount);

        //record how many vcoind is transfer to targetSc
        assetInfoMap[_user].finalAsset =  assetInfoMap[_user].finalAsset.add(_vCoinAmount);

        emit TransferVCoinToTarget(_user,targetSc,_vCoinAmount);

        return _vCoinAmount;
    }

    //only transfer user's usdc coin if allowed to withdraw
    function withdraw()
         notHalted
         nonReentrant
         external
    {
        require(allowWithdraw,"withdraw is not allowed!");

        uint256 amount = assetInfoMap[msg.sender].originAsset;
        assetInfoMap[msg.sender].originAsset = 0;
        assetInfoMap[msg.sender].baseAsset = 0;
        IERC20(coin).transfer(msg.sender, amount);
        emit Withdraw(coin,msg.sender,amount);
    }

    //transfer usdc coin in sc to target sc if multisig permit
    function TransferCoinToTarget() public onlyOrigin {
        uint256 coinBal = IERC20(coin).balanceOf(address(this));
        IERC20(coin).transfer(targetSc, coinBal);
        emit TransferToTarget(msg.sender,targetSc,coinBal);
    }

    function getUserBalanceInfo(address _user)public view returns(uint256,uint256,uint256){
        if(interestInterval == 0){
            return (0,0,0);
        }
        uint256 vAsset = getAssetBalance(_user);
        return (assetInfoMap[_user].originAsset,vAsset,assetInfoMap[_user].finalAsset);
    }

    function getInterestInfo()external view returns(uint256,uint256){
        return (interestRate,interestInterval);
    }

    function _setInterestInfo(uint256 _interestRate,uint256 _interestInterval,uint256 _maxRate,uint256 _minRate) internal {
        if (accumulatedRate == 0){
            accumulatedRate = rayDecimals;
        }
        require(_interestRate<=1e27,"input stability fee is too large");
        require(_interestInterval>0,"input mine Interval must larger than zero");
        uint256 newLimit = rpower(uint256(1e27+_interestRate),31536000/_interestInterval,rayDecimals);
        require(newLimit<= _maxRate && newLimit>= _minRate,"input rate is out of range");

        _interestSettlement();
        interestRate = _interestRate;
        interestInterval = _interestInterval;

        emit SetInterestInfo(msg.sender,_interestRate,_interestInterval);
    }

    function getAssetBalance(address account)public view returns(uint256){
        return calInterestAmount(assetInfoMap[account].baseAsset,newAccumulatedRate());
    }

    function rpower(uint256 x, uint256 n, uint256 base) internal pure returns (uint256 z) {
        assembly {
            switch x case 0 {switch n case 0 {z := base} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := base } default { z := x }
                let half := div(base, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                let xx := mul(x, x)
                if iszero(eq(div(xx, x), x)) { revert(0,0) }
                let xxRound := add(xx, half)
                if lt(xxRound, xx) { revert(0,0) }
                x := div(xxRound, base)
                if mod(n,2) {
                    let zx := mul(z, x)
                    if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                    let zxRound := add(zx, half)
                    if lt(zxRound, zx) { revert(0,0) }
                    z := div(zxRound, base)
                }
            }
            }
        }
    }

//    modifier settleInterest(){
//        _interestSettlement();
//        _;
//    }
    /**
     * @dev the auxiliary function for _mineSettlementAll.
     */
    function _interestSettlement()internal{
        uint256 _interestInterval = interestInterval;
        if (_interestInterval>0){
            accumulatedRate = newAccumulatedRate();
            latestSettleTime = currentTime()/_interestInterval*_interestInterval;
        }else{
            latestSettleTime = currentTime();
        }
    }

    function newAccumulatedRate()internal  view returns (uint256){
        uint256 newRate = rpower(uint256(rayDecimals+interestRate),(currentTime()-latestSettleTime)/interestInterval,rayDecimals);
        return accumulatedRate.mul(newRate)/rayDecimals;
    }

    function currentTime() internal view returns (uint256){
        return block.timestamp;
    }

    function calBaseAmount(uint256 amount, uint256 _interestRate) internal pure returns(uint256){
        return amount.mul(InterestDecimals)/_interestRate;
    }

    function calInterestAmount(uint256 amount, uint256 _interestRate) internal pure returns(uint256){
        return amount.mul(_interestRate)/InterestDecimals;
    }

}
