// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.15;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./interfaces/IPancake.sol";
import "./mixins/SafeMathInt.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/INFT.sol";

contract BabiesOfMars is ERC20Upgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeMathInt for int256;

    event LogRebase(uint256 indexed epoch, uint256 totalSupply);

    string public _name = "BabiesOfMars";
    string public _symbol = "BoM";
    uint8 public _decimals = 5;

    IPancakeSwapPair public pairContract;
    mapping(address => bool) _isFeeExempt;

    modifier validRecipient(address to) {
        require(to != address(0x0));
        _;
    }

    modifier onlyAdmin() {
        require(treasury.isAdmin(msg.sender));
        _;
    }

    uint256 public constant DECIMALS = 5;
    uint256 public constant MAX_UINT256 = ~uint256(0);
    uint8 public constant RATE_DECIMALS = 7;

    uint256 public feeDenominator = 10000;

    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;

    address public autoLiquidityReceiver;
    ITreasury public treasury;
    address public redTrustWallet;
    address public redFurnace;
    address public pairAddress;
    INFT public nftRewardPool;
    bool public swapEnabled = true;
    IPancakeSwapRouter public router;
    IPancakeSwapPair public pair;
    bool inSwap = false;

    uint256 lastPrice;
    uint256 defenderTimer;
    uint256 accumulatedImpact;
    bool rdStatus;

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    uint256 private constant TOTAL_GONS =
        MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 50_000 * 10**DECIMALS;
    uint256 private constant MAX_SUPPLY = 500_000 * 10**DECIMALS;

    bool public _autoRebase;
    bool public _autoAddLiquidity;
    uint256 public _initRebaseStartTime;
    uint256 public _lastRebasedTime;
    uint256 public _lastAddLiquidityTime;
    uint256 public _totalSupply;
    uint256 private _gonsPerFragment;

    uint256 public rebaseInterval = 15 minutes;

    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowedFragments;
    mapping(address => bool) public blacklist;

    function initialize(
        address _router,
        address _owner,
        ITreasury _treasury,
        address _redTrustWallet,
        INFT _nftRewardPool,
        address _redFurnace
    ) public initializer {
        __ERC20_init(_name, _symbol);
        router = IPancakeSwapRouter(_router);
        pair = IPancakeSwapPair(
            IPancakeSwapFactory(router.factory()).createPair(
                router.WETH(),
                address(this)
            )
        );

        autoLiquidityReceiver = DEAD;
        treasury = _treasury;
        redTrustWallet = _redTrustWallet;
        redFurnace = _redFurnace;
        nftRewardPool = _nftRewardPool;

        _allowedFragments[address(this)][address(router)] = type(uint256).max;
        pairContract = IPancakeSwapPair(pair);

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonBalances[_owner] = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
        _initRebaseStartTime = block.timestamp;
        _lastRebasedTime = block.timestamp;
        _autoRebase = false;
        _autoAddLiquidity = true;
        _isFeeExempt[_owner] = true;
        _isFeeExempt[address(this)] = true;
        _isFeeExempt[redTrustWallet] = true;
        _isFeeExempt[address(nftRewardPool)] = true;
        _isFeeExempt[address(treasury)] = true;

        defenderTimer = block.timestamp;

        emit Transfer(address(0x0), _owner, _totalSupply);
    }

    function rebase() internal {
        if (inSwap) return;
        uint256 rebaseRate;
        uint256 deltaTimeFromInit = block.timestamp - _initRebaseStartTime;
        uint256 deltaTime = block.timestamp - _lastRebasedTime;
        uint256 times = deltaTime.div(rebaseInterval);
        uint256 epoch = times.mul(15);

        if (deltaTimeFromInit < (365 days)) {
            rebaseRate = 2731;
        } else if (deltaTimeFromInit >= (365 days)) {
            rebaseRate = 211;
        } else if (deltaTimeFromInit >= ((15 * 365 days) / 10)) {
            rebaseRate = 14;
        } else if (deltaTimeFromInit >= (7 * 365 days)) {
            rebaseRate = 2;
        }

        for (uint256 i = 0; i < times; i++) {
            _totalSupply = _totalSupply
                .mul((10**RATE_DECIMALS).add(rebaseRate))
                .div(10**RATE_DECIMALS);
        }

        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
        _lastRebasedTime = _lastRebasedTime.add(times.mul(rebaseInterval));

        pairContract.sync();

        emit LogRebase(epoch, _totalSupply);
    }

    function transfer(address to, uint256 value)
        public
        override
        validRecipient(to)
        returns (bool)
    {
        _transferFrom(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override validRecipient(to) returns (bool) {
        if (_allowedFragments[from][msg.sender] != type(uint256).max) {
            _allowedFragments[from][msg.sender] = _allowedFragments[from][
                msg.sender
            ].sub(value, "Insufficient Allowance");
        }
        _transferFrom(from, to, value);
        return true;
    }

    function _basicTransfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        uint256 gonAmount = amount.mul(_gonsPerFragment);
        _gonBalances[from] = _gonBalances[from].sub(gonAmount);
        _gonBalances[to] = _gonBalances[to].add(gonAmount);
        return true;
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        require(!blacklist[sender] && !blacklist[recipient], "in_blacklist");

        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }
        if (shouldRebase()) {
            rebase();
        }

        if (shouldAddLiquidity()) {
            addLiquidity();
        }

        uint256 gonAmount = amount.mul(_gonsPerFragment);
        _gonBalances[sender] = _gonBalances[sender].sub(gonAmount);
        uint256 gonAmountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, recipient, gonAmount)
            : gonAmount;
        _gonBalances[recipient] = _gonBalances[recipient].add(
            gonAmountReceived
        );

        emit Transfer(
            sender,
            recipient,
            gonAmountReceived.div(_gonsPerFragment)
        );
        return true;
    }

    function takeFee(
        address sender,
        address recipient,
        uint256 gonAmount
    ) internal returns (uint256) {
        (uint256 impact, uint256 oldPrice, uint256 newPrice) = getImpact(
            gonAmount
        );

        // deactivate defender if 1 hour window has passed
        if (rdStatus == true) {
            if (block.timestamp - defenderTimer > 1 hours) {
                rdStatus = false;
                defenderTimer = block.timestamp.sub(1);
                accumulatedImpact = 1;
            }
        }

        uint256 impactTax;
        uint256 feeAmount;

        // sell
        if (recipient == address(pair)) {
            if (block.timestamp - defenderTimer < 1 hours) {
                // add impact to accumulator
                accumulatedImpact = accumulatedImpact.add(impact);
            } else {
                // window has passed, reset accumulator
                accumulatedImpact = impact;
                defenderTimer = block.timestamp;
            }

            require(accumulatedImpact <= 500, "price impact is too large");

            // activate defender if accumulated impact is > 1%
            if (accumulatedImpact > 100) {
                rdStatus = true;
                defenderTimer = block.timestamp;
            } else {
                impactTax = ((gonAmount * impact) / 1000) * 4;
            }

            if (rdStatus) {
                feeAmount = distributeFees(500, 1000, 100 + 4 * impact, 0, 0, gonAmount);
            } else {
                feeAmount = distributeFees(400, 500, 500 + 4 * impact, 200, 300, gonAmount);
            }
        } else {  // buy
            if (rdStatus) {
                feeAmount = distributeFees(200, 500, 300, 0, 0, gonAmount);
            } else {
                feeAmount = distributeFees(400, 500, 300, 200, 300, gonAmount);
            }
        }

        return gonAmount.sub(feeAmount);
    }

    function distributeFees(uint256 liquidityFee, uint256 rtfFee, uint256 rtFee, uint256 rfFee, uint256 rewardFee, uint256 gonAmount) private returns (uint256) {
        uint256 _totalFee = liquidityFee.add(rtfFee);
        _totalFee = _totalFee.add(rtFee);
        _totalFee = _totalFee.add(rfFee);
        _totalFee = _totalFee.add(rewardFee);
        uint256 feeAmount = gonAmount.mul(_totalFee).div(feeDenominator);

        _gonBalances[redFurnace] = _gonBalances[redFurnace].add(
            gonAmount.mul(rfFee).div(feeDenominator)
        );
        _gonBalances[address(treasury)] = _gonBalances[address(treasury)].add(
            gonAmount.mul(rtFee).div(feeDenominator)
        );
        _gonBalances[redTrustWallet] = _gonBalances[redTrustWallet].add(
            gonAmount.mul(rtfFee).div(feeDenominator)
        );
        _gonBalances[autoLiquidityReceiver] = _gonBalances[
        autoLiquidityReceiver
        ].add(gonAmount.mul(liquidityFee).div(feeDenominator));
        approve(address(nftRewardPool), rewardFee);
        nftRewardPool.raiseRewardPool(rewardFee);

        emit Transfer(msg.sender, address(treasury), rtFee.div(_gonsPerFragment));
        emit Transfer(msg.sender, redTrustWallet, rtfFee.div(_gonsPerFragment));
        emit Transfer(msg.sender, redFurnace, rfFee.div(_gonsPerFragment));
        emit Transfer(msg.sender, autoLiquidityReceiver, liquidityFee.div(_gonsPerFragment));

        return feeAmount;
    }

    function getImpact(uint256 amount)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 price0 = pair.price0CumulativeLast();
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        uint256 constProduct = reserve0 * reserve1;
        uint256 new1Amount = reserve1 + amount;
        uint256 new0Amount = constProduct / new1Amount;
        uint256 amountTradedFor = reserve1 - new0Amount;
        uint256 new0Price = amount / amountTradedFor;
        return (((new0Price - price0) / price0) * 10000, price0, new0Price);
        // return (amount*priceImpact/1000)*4;
    }

    function addLiquidity() internal swapping {
        uint256 autoLiquidityAmount = _gonBalances[autoLiquidityReceiver].div(
            _gonsPerFragment
        );
        _gonBalances[address(this)] = _gonBalances[address(this)].add(
            _gonBalances[autoLiquidityReceiver]
        );
        _gonBalances[autoLiquidityReceiver] = 0;
        uint256 amountToLiquify = autoLiquidityAmount.div(2);
        uint256 amountToSwap = autoLiquidityAmount.sub(amountToLiquify);

        if (amountToSwap == 0) {
            return;
        }
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        uint256 balanceBefore = address(this).balance;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountETHLiquidity = address(this).balance.sub(balanceBefore);

        if (amountToLiquify > 0 && amountETHLiquidity > 0) {
            router.addLiquidityETH{value: amountETHLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                DEAD,
                block.timestamp
            );
        }
        _lastAddLiquidityTime = block.timestamp;
    }

    function withdrawAllToTreasury() public swapping onlyAdmin {
        uint256 amountToSwap = _gonBalances[address(this)].div(
            _gonsPerFragment
        );
        require(
            amountToSwap > 0,
            "There is no token deposited in token contract"
        );
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(treasury),
            block.timestamp
        );
    }

    function shouldTakeFee(address from, address to)
        internal
        view
        returns (bool)
    {
        return
            (address(pair) == from || address(pair) == to) &&
            !_isFeeExempt[from] &&
            !_isFeeExempt[to];
    }

    function shouldRebase() internal view returns (bool) {
        return
            _autoRebase &&
            (_totalSupply < MAX_SUPPLY) &&
            msg.sender != address(pair) &&
            !inSwap &&
            block.timestamp >= (_lastRebasedTime + rebaseInterval);
    }

    function shouldAddLiquidity() internal view returns (bool) {
        return
            _autoAddLiquidity &&
            !inSwap &&
            msg.sender != address(pair) &&
            block.timestamp >= (_lastAddLiquidityTime + 48 hours);
    }

    function shouldSwapBack() internal view returns (bool) {
        return !inSwap && msg.sender != address(pair);
    }

    function setAutoRebase(bool _flag) public onlyAdmin {
        if (_flag) {
            _autoRebase = _flag;
            _lastRebasedTime = block.timestamp;
        } else {
            _autoRebase = _flag;
        }
    }

    function setAutoAddLiquidity(bool _flag) public onlyAdmin {
        if (_flag) {
            _autoAddLiquidity = _flag;
            _lastAddLiquidityTime = block.timestamp;
        } else {
            _autoAddLiquidity = _flag;
        }
    }

    function allowance(address owner_, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowedFragments[owner_][spender];
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        override
        returns (bool)
    {
        uint256 oldValue = _allowedFragments[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedFragments[msg.sender][spender] = 0;
        } else {
            _allowedFragments[msg.sender][spender] = oldValue.sub(
                subtractedValue
            );
        }
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        override
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = _allowedFragments[msg.sender][
            spender
        ].add(addedValue);
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function approve(address spender, uint256 value)
        public
        override
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function checkFeeExempt(address _addr) public view returns (bool) {
        return _isFeeExempt[_addr];
    }

    function getCirculatingSupply() public view returns (uint256) {
        return
            (TOTAL_GONS.sub(_gonBalances[DEAD]).sub(_gonBalances[ZERO])).div(
                _gonsPerFragment
            );
    }

    function isNotInSwap() public view returns (bool) {
        return !inSwap;
    }

    function manualSync() public {
        IPancakeSwapPair(pair).sync();
    }

    function setFeeReceivers(
        ITreasury _treasury,
        address _redTrustWallet,
        address _redFurnace
    ) public onlyAdmin {
        treasury = _treasury;
        redTrustWallet = _redTrustWallet;
        redFurnace = _redFurnace;
    }

    function getLiquidityBacking(uint256 accuracy)
        public
        view
        returns (uint256)
    {
        uint256 liquidityBalance = _gonBalances[address(pair)].div(
            _gonsPerFragment
        );
        return
            accuracy.mul(liquidityBalance.mul(2)).div(getCirculatingSupply());
    }

    function setWhitelist(address _addr) public onlyAdmin {
        _isFeeExempt[_addr] = true;
    }

    function setBotBlacklist(address _botAddress, bool _flag) public onlyAdmin {
        require(
            isContract(_botAddress),
            "only contract address, not allowed exteranlly owned account"
        );
        blacklist[_botAddress] = _flag;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address who) public view override returns (uint256) {
        return _gonBalances[who].div(_gonsPerFragment);
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    receive() external payable {}
}
