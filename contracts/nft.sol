// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.14;
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/Base64Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ITreasury.sol";
import "./interfaces/IPancakeSwapPair.sol";
import "./mixins/signature-control.sol";
import "./interfaces/INFT.sol";
import "./interfaces/INFTMetadata.sol";

contract NFT is ERC721EnumerableUpgradeable, SignatureControl, INFT {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    //variables
    bool pause;
    uint256 nonce;
    ITreasury treasury;
    IERC20Upgradeable BoM;
    address redTrustFund;
    IPancakeSwapPair public pairContract;
    IPancakeSwapRouter public swapRouter;

    uint256 treasuryFee;
    uint256 redTrustFee;
    uint256 rewardPoolFee;

    uint256 supply;

    uint256 public wethInRewardPool;
    uint256 busdInLotteryPool;
    uint256 public totalClaimed;

    mapping(uint256 => uint256) mintCapOfToken;
    mapping(uint256 => address[]) tokenIdToType;
    mapping(address => mapping(uint256 => uint256)) tokensOwnedOfType;
    mapping(uint256 => bool) usedNonces;

    //mint prices, caps, addresses of reward tokens(shiba,floki,doggy,doge)
    uint256[4] prices;
    //  = [
        // .001 ether,
        // .0008 ether,
        // .0006 ether,
        // .0004 ether
//        300 * 10**18,
//        250 * 10**18,
//        200 * 10**18,
//        250 * 10**18
    // ];
    INFTMetadata metadata;
    IERC20Upgradeable BUSD;
    IERC20Upgradeable WETH;
    mapping(address => uint256) tokenToPrices;
    uint256[4] nftCaps;
    address[4] public rewardTokens;
    mapping(address => uint256) addressToType;
    mapping(address => uint256) totalRatesForType;
    mapping(address => mapping(address => uint256)) addrerssToRatesForType;

    uint256[5] rewardPoolForToken;
    uint256[5] rewardsPerShareStored;
    uint256[5] lastUpdatePools;
    mapping(address => uint256[5]) accountShares;
    uint256[5] totalShares;
    mapping(address => mapping(uint256 => uint256)) accountRewards;
    mapping(address => mapping(uint256 => uint256)) accountRewardsPerTokenPaid;

    bool public isPresale;
    uint256 whitelistPrice;
    uint256 constant maxMintPerAddressDuringWhitelist = 5;
    uint256 constant whitelistMintCapPerType = 250;
    mapping(address => bool) isWhitelisted;
    mapping(address => uint256) mintedOnWhitelist;
    mapping(uint256 => uint256) whitelistMintCapOfToken;

    EnumerableSetUpgradeable.AddressSet _holders;  // TODO: migrate?

    uint256 constant statMultiplier = 100000;
    mapping(uint256 => TokenInfo) tokenIdToInfo;

    mapping(address => Tokenomic) addressToToken;
    struct Tokenomic {
        uint256 stakingRate;
        uint256 attack;
        uint256 defense;
        uint256 health;
        uint256 critChance;
        uint256 critDmg;
        uint256 recovery;
    }

    event TokenMinted(
        address indexed minter,
        uint256 tokenId,
        address token,
        uint256 rate
    );

    event TokenCombined(
        address indexed user,
        uint256[] burntTokens,
        address[] tokens,
        uint256 tokenId,
        uint256 rate
    );

    event RewardPoolRaised(uint256 amount);
    event LotteryPoolRaised(uint256 amount);

    //modifiers
    modifier onlyAdmin() {
        require(treasury.isAdmin(msg.sender), "!admin");
        _;
    }

    modifier isUnpaused() {
        require(!pause, "paused");
        _;
    }

    modifier isValidWhitelistMint(uint256 amount, uint256 tokenType) {
        require(isPresale, "!presale");
        require(isWhitelisted[msg.sender], "!whitelisted");
        require(
            mintedOnWhitelist[msg.sender] + amount <=
                maxMintPerAddressDuringWhitelist, "maxMint exceeded"
        );
        require(tokenType <= 3, "!tokenType");
        require(
            whitelistMintCapOfToken[tokenType] + amount <=
                whitelistMintCapPerType, "mintCap exceeded"
        );
        _;
    }

    modifier isValidMint(uint256 amount, uint256 tokenType) {
        require(!isPresale, "presale");
        require(tokenType <= 3, "!tokenType");
        require(mintCapOfToken[tokenType] + amount <= nftCaps[tokenType]);
        _;
    }

    modifier isValidCombine(uint256[] memory tokenIds) {
        require(tokenIds.length > 1 && tokenIds.length <= 4, "wrong tokenIds length");
        bool hasDupes;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == msg.sender, "!owner");
            require(tokenIdToType[tokenIds[i]].length == 1, "!tokenIdToType");
            for (uint256 index = i; index < tokenIds.length; index++) {
                if (
                    index != i &&
                    tokenIdToType[tokenIds[i]][0] ==
                    tokenIdToType[tokenIds[index]][0]
                ) {
                    hasDupes = true;
                }
            }
            require(!hasDupes, "dupes");
        }
        _;
    }

    function initialize(
        string memory name,
        string memory symbol,
        ITreasury _treasury,
        address _redTrustFund,
        IERC20Upgradeable token,
        uint256 _rewardFee,
        uint256 _treasuryFee,
        uint256 _redTrustFee,
        IPancakeSwapPair _pair,
        IPancakeSwapRouter _router,
        IERC20Upgradeable _BUSD,
        IERC20Upgradeable _WETH
    ) public initializer {
        _initialize(name, symbol);
        treasury = _treasury;
        BoM = token;
        redTrustFund = _redTrustFund;
        rewardPoolFee = _rewardFee;
        redTrustFee = _redTrustFee;
        treasuryFee = _treasuryFee;
        uint16[4] memory attack = [1000, 1000, 700, 850];
        uint16[4] memory defense = [800, 1000, 850, 1000];
        uint16[4] memory health = [800, 800, 1000, 850];
        uint16[4] memory critChance = [400, 200, 400, 300];
        uint16[4] memory critDmg = [600, 500, 800, 500];
        uint16[4] memory recovery = [600, 700, 1000, 900];
        for (uint256 i = 0; i < 4; i++) {
            addressToToken[rewardTokens[i]].attack = attack[i];
            addressToToken[rewardTokens[i]].defense = defense[i];
            addressToToken[rewardTokens[i]].health = health[i];
            addressToToken[rewardTokens[i]].critChance = critChance[i];
            addressToToken[rewardTokens[i]].critDmg = critDmg[i];
            addressToToken[rewardTokens[i]].recovery = recovery[i];
            tokenToPrices[rewardTokens[i]] = prices[i];
            addressToType[rewardTokens[i]] = i;
        }
        pairContract = _pair;
        swapRouter = _router;
        BUSD = _BUSD;
        WETH = _WETH;
    }

    function _initialize(string memory name, string memory symbol) internal {
        __ERC721_init(name, symbol);
        prices = [
            .001 ether,
            .0008 ether,
            .0006 ether,
            .0004 ether
        ];
        isPresale = true;
        whitelistPrice = .003 ether;
        nftCaps = [1000, 1500, 2000, 1500];
        rewardTokens = [
        0x0000000000000000000000000000000000000000,
        0x0000000000000000000000000000000000000001,
        0x0000000000000000000000000000000000000002,
        0x0000000000000000000000000000000000000003
        ];
    }

    function addWhitelist(address[] memory whitelist) public onlyAdmin {
        for (uint256 i = 0; i < whitelist.length; i++) {
            isWhitelisted[whitelist[i]] = true;
        }
    }

    function mintPresale(uint256 amount, uint256 tokenType)
        public
        isUnpaused
        isValidWhitelistMint(amount, tokenType)
    {
        for (uint256 i = 0; i < amount; i++) {
            supply++;
            tokenIdToInfo[supply].tokens.push(rewardTokens[tokenType]);
            tokenIdToType[supply].push(rewardTokens[tokenType]);
            uint256 rate = createTokenStats(supply);
            _mint(msg.sender, supply);
            emit TokenMinted(msg.sender, supply, rewardTokens[tokenType], rate);
        }
        mintedOnWhitelist[msg.sender] += amount;
        whitelistMintCapOfToken[tokenType] += amount;
        mintCapOfToken[tokenType] += amount;
        //TBD: swap to bnb
        _distributeFunds(amount * whitelistPrice);
    }

    function mint(uint256 amount, uint256 tokenType)
        public
        isUnpaused
        isValidMint(amount, tokenType)
    {
        for (uint256 i = 0; i < amount; i++) {
            supply++;
            tokenIdToInfo[supply].tokens.push(rewardTokens[tokenType]);
            tokenIdToType[supply].push(rewardTokens[tokenType]);
            uint256 rate = createTokenStats(supply);
            _mint(msg.sender, supply);
            emit TokenMinted(msg.sender, supply, rewardTokens[tokenType], rate);
        }
        mintCapOfToken[tokenType] += amount;
        //TBD: swap to bnb
        _distributeFunds(amount * prices[tokenType]);
    }

    function combineTokens(uint256[] memory tokenIds)
        public
        payable
        isUnpaused
    {
        require(msg.value == 0.05 ether, "!value");
        supply++;
        uint256 price;
        address[] memory tokens = new address[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            TokenInfo memory token = tokenIdToInfo[tokenIds[i]];
            address intermediateStorageForToken = tokenIdToType[tokenIds[i]][0];
            tokenIdToInfo[supply].tokens.push(intermediateStorageForToken);
            tokenIdToType[supply].push(intermediateStorageForToken);
            tokens[i] = intermediateStorageForToken;
            _burn(tokenIds[i]);
            price += tokenToPrices[tokenIdToType[tokenIds[i]][0]] / 4;
            for (uint256 index = 0; index < token.tokens.length; index++) {
                totalRatesForType[token.tokens[index]] -= token.rate;
            }
        }
        uint256 rate = createTokenStats(supply);
        _mint(msg.sender, supply);
        emit TokenCombined(msg.sender, tokenIds, tokens, supply, rate);

        //TBD: calculate price with usd in mind
        _distributeFunds(price);
    }

    function createTokenStats(uint256 tokenId) internal returns (uint256 rate) {
        TokenInfo storage token = tokenIdToInfo[tokenId];
        uint256[7] memory seeds;
        for (uint8 i = 0; i < 7; i++) {
            nonce++;
            seeds[i] = (
                uint256(
                    keccak256(
                        abi.encodePacked(msg.sender, block.timestamp, nonce)
                    )
                )
            );
        }
        if (token.tokens.length == 1) {
            uint256 rateMod = (seeds[0] % 100) + 1;
            if (rateMod == 1) {
                token.rate = 2000;
            } else if (rateMod <= 3) {
                token.rate = 1750;
            } else if (rateMod <= 10) {
                token.rate = 1500;
            } else if (rateMod <= 20) {
                token.rate = 1250;
            } else {
                token.rate = 1000;
            }
        } else if (token.tokens.length == 2) {
            token.rate = 2250;
        } else if (token.tokens.length == 3) {
            token.rate = 2500;
        } else {
            token.rate = 3000;
        }
        rate = token.rate;
        for (uint256 i = 0; i < token.tokens.length; i++) {
            totalRatesForType[token.tokens[i]] += token.rate;
        }
        createBattleStats(seeds, token, getStatMultipliers(token));
    }

    function createBattleStats(
        uint256[7] memory seeds,
        TokenInfo storage token,
        uint256[6] memory statMultipliers
    ) internal {
        token.attack =
            (((seeds[1] % 71) + 30) * (token.rate * statMultipliers[0])) /
            statMultiplier;
        token.defense =
            (((seeds[2] % 71) + 30) * (token.rate * statMultipliers[1])) /
            statMultiplier;
        token.health =
            (((seeds[3] % 51) + 50) * (token.rate * statMultipliers[2])) /
            statMultiplier;
        token.critChance =
            (((seeds[4] % 41) + 30) * (token.rate * statMultipliers[3])) /
            statMultiplier;
        token.critDmg =
            (((seeds[5] % 61) + 10) * (token.rate * statMultipliers[4])) /
            statMultiplier;
        token.recover =
            (((seeds[6] % 51) + 50) * (token.rate * statMultipliers[5])) /
            statMultiplier;
    }

    function getStatMultipliers(TokenInfo storage token)
        internal
        view
        returns (uint256[6] memory statMultipliers)
    {
        uint16[4] memory megaStatMultipliers = [1000, 1250, 1500, 2000];
        for (uint8 i = 0; i < token.tokens.length; i++) {
            Tokenomic memory tokenomic = addressToToken[token.tokens[i]];
            statMultipliers[0] += tokenomic.attack;
            statMultipliers[1] += tokenomic.defense;
            statMultipliers[2] += tokenomic.health;
            statMultipliers[3] += tokenomic.critChance;
            statMultipliers[4] += tokenomic.critDmg;
            statMultipliers[5] += tokenomic.recovery;
        }
        for (uint8 i = 0; i < 6; i++) {
            statMultipliers[i] =
                (statMultipliers[i] / token.tokens.length) *
                megaStatMultipliers[token.tokens.length - 1];
        }
    }

    function _distributeFunds(uint256 amount) internal {
        uint256[] memory requiredAmountOfTokens = _getAmountsIn(
            amount,
            address(BoM),
            address(WETH)
        );
        require(
            BoM.allowance(msg.sender, address(this)) >=
                requiredAmountOfTokens[0],
            "allowance too low"
        );
        BoM.transferFrom(msg.sender, address(this), requiredAmountOfTokens[0]);
        uint256 bnbAmount = _swap(
            amount,
            requiredAmountOfTokens[0],
            address(BoM),
            address(WETH)
        )[0];
        uint256 _treasuryFee = (bnbAmount * treasuryFee) / 1000;
        uint256 _redTrustFee = (bnbAmount * redTrustFee) / 1000;
        uint256 _rewardPoolFee = bnbAmount - _treasuryFee - _redTrustFee;
        BoM.transferFrom(msg.sender, address(treasury), _treasuryFee);
        BoM.transferFrom(msg.sender, redTrustFund, _redTrustFee);
        BoM.transferFrom(msg.sender, address(this), _rewardPoolFee);
        _addToPool(_rewardPoolFee);
    }

    function lottery() public onlyAdmin {
        require(busdInLotteryPool > 0, "no funds in lottery pool");

        uint256[10] memory seeds;

        uint256 holdersCount = _holders.length();
        uint256 winnersCount = holdersCount;
        if (winnersCount > 10) {
            winnersCount = 10;

            for (uint8 i = 0; i < winnersCount; i++) {
                nonce++;
                uint256 idx = (
                    uint256(
                        keccak256(
                            abi.encodePacked(msg.sender, block.timestamp, blockhash(block.number - 1), nonce)
                        )
                    )
                ) % holdersCount;

                while (true) {
                    bool retry = false;
                    for (uint8 j=0; j < i; j++) {
                        if (idx == seeds[j]) {
                            retry = true;
                            idx = (idx + 1) % holdersCount;
                            break;
                        }
                    }
                    if (!retry)
                        break;
                }

                seeds[i] = idx;
            }
        } else {
            for (uint8 i=0; i < winnersCount; i++) {
                seeds[i] = i;
            }
        }

        uint256 winEach = 100 ether;
        if (busdInLotteryPool < (100 ether * winnersCount))
            winEach = busdInLotteryPool / winnersCount;

        for (uint256 i = 0; i < winnersCount; i++) {
            BUSD.safeTransfer(_holders.at(seeds[i]), winEach);
        }
    }

    function _getAmountsIn(
        uint256 price,
        address path0,
        address path1
    ) internal view returns (uint256[] memory) {
        address[] memory path = new address[](2);
        path[0] = path0;
        path[1] = path1;
        return swapRouter.getAmountsIn(price, path);
    }

    function _swap(
        uint256 amount,
        uint256 price,
        address path0,
        address path1
    ) internal returns (uint256[] memory) {
        IERC20(path0).approve(address(swapRouter), 2**256-1);
        address[] memory path = new address[](2);
        path[0] = path0;
        path[1] = path1;
        return
            swapRouter.swapTokensForExactTokens(
                amount,
                price,
                path,
                address(this),
                block.timestamp
            );
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Non-existent token");
        TokenInfo memory token = tokenIdToInfo[tokenId];
        return metadata.tokenURI(tokenId, token);
    }

    function raiseRewardPool(uint256 amount) public {
        require(
            BoM.allowance(msg.sender, address(this)) >= amount,
            "Not enough allowance"
        );
        BoM.transferFrom(msg.sender, address(this), amount);
        _addToPool(amount);
    }

    function _addToPool(uint256 amount) internal {
        uint256 lotteryPoolAmount = amount / 10;

        address[] memory path = new address[](2);
        path[0] = address(BoM);
        path[1] = address(BUSD);

        IERC20(address(BoM)).approve(address(swapRouter), amount);
        uint256 swappedFor = swapRouter.swapExactTokensForTokens(
            lotteryPoolAmount,  // 10% to lottery
            0,
            path,
            address(this),
            block.timestamp
        )[0];
        busdInLotteryPool += swappedFor;
        emit LotteryPoolRaised(swappedFor);


        path[1] = address(WETH);
        swappedFor = swapRouter.swapExactTokensForTokens(
            amount - lotteryPoolAmount,
            0,
            path,
            address(this),
            block.timestamp
        )[0];
        wethInRewardPool += swappedFor;
        for (uint8 i=0; i < 4; i++) {
            rewardPoolForToken[i] += swappedFor * 2 / 9;  // 20% of total each
        }
        rewardPoolForToken[4] += swappedFor - swappedFor * 8 / 9;  // remaining 10%
        emit RewardPoolRaised(swappedFor);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._afterTokenTransfer(from, to, tokenId);
        TokenInfo memory info = tokenIdToInfo[tokenId];
        if (from != address(0)) {
            if (balanceOf(from) == 0) {
                _holders.remove(from);
            }
            if (info.tokens.length > 1) {
                totalShares[4] -= info.rate;
                accountShares[from][4] -= info.rate;
            } else {
                uint256 idx = addressToType[info.tokens[0]];
                totalShares[idx] -= info.rate;
                accountShares[from][idx] -= info.rate;
            }
        }
        if (to != address(0)) {
            _holders.add(to);
            if (info.tokens.length > 1) {
                totalShares[4] += info.rate;
                accountShares[to][4] += info.rate;
            } else {
                uint256 idx = addressToType[info.tokens[0]];
                totalShares[idx] += info.rate;
                accountShares[to][idx] += info.rate;
            }
        }
    }

    function pendingReward(uint256 idx, address account) public view returns (uint256) {
        return accountShares[account][idx] + (_rewardPerShare(idx) - accountRewardsPerTokenPaid[account][idx]) / 1e18 + accountRewards[account][idx];
    }

    function _rewardPerShare(uint256 idx) internal view returns (uint256) {
        if (totalShares[idx] == 0)
            return rewardsPerShareStored[idx];
        return rewardsPerShareStored[idx] + (rewardPoolForToken[idx] - lastUpdatePools[idx]) / totalShares[idx];
    }

    function _updateRewards(address account) internal {
        for (uint256 i=0; i < 5; i++) {
            rewardsPerShareStored[i] = _rewardPerShare(i);
            lastUpdatePools[i] = rewardPoolForToken[i];
            if (account != address(0)) {
                accountRewards[account][i] = pendingReward(i, account);
                accountRewardsPerTokenPaid[account][i] = rewardsPerShareStored[i];
            }
        }
    }

    function claimReward(uint256 idx) external {
        _updateRewards(msg.sender);
        uint256 reward = accountRewards[msg.sender][idx];
        require(reward > 0, "nothing to claim");
        accountRewards[msg.sender][idx] = 0;
        totalClaimed==reward;

        IERC20(address(WETH)).approve(address(swapRouter), reward);
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = rewardTokens[idx];
        uint256 swappedFor = swapRouter.swapExactTokensForTokens(
            reward,
            0,
            path,
            msg.sender,
            block.timestamp
        )[0];
    }

    function togglePause() external onlyAdmin {
        pause = !pause;
    }

    function finishPresale() external onlyAdmin {
        require(isPresale, "!presale");
        isPresale = false;
    }

    function updateMetadata(INFTMetadata newValue) external onlyAdmin {
        metadata = newValue;
    }
}
