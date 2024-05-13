//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Presale is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    enum DepositCurrency {
        COIN,
        USDT,
        CARD
    }
    struct UserDeposit {
        address depositAddresse;
        uint256 depositAmount;
        uint256 tokenAmount;
        DepositCurrency currency;
        uint256 stage;
        uint256 currencyPrice;
    }
    struct PurchaseData {
        uint256 tokenAmount;
        string username;
        string transactionId;
    }

    address oracle;
    address usdt;
    address withdrawAddress;
    address oraclePriceFeed;

    uint256 MAX_PRESALE;
    uint256 public totalPurcharsedToken;
    uint256 public stagePurcharsedToken;

    mapping(string => UserDeposit[]) userDeposits;
    mapping(uint256 => uint256) stageStepTokens;

    event BuyToken(
        string indexed username,
        address indexed depositAddress,
        string usernameStr,
        string transactionId,
        uint256 stage,
        uint256 stagePrice,
        uint256 purchaseTokenAmount,
        uint256 currencyPrice,
        DepositCurrency currency,
        uint256 timestamp
    );
    /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() {
    //     _disableInitializers();
    // }

    function initialize(
        address initialOwner,
        address _oracle,
        address _usdt,
        address _oraclePriceFeed
    ) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        oracle = _oracle;
        usdt = _usdt;
        withdrawAddress = initialOwner;
        oraclePriceFeed = _oraclePriceFeed;
        MAX_PRESALE = 4 * 10 ** 10 * 10 ** 18;
    }

    /**
     * @dev To pause the presale
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev To unpause the presale
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev To buy token with USDT
     */
    function buyWithUSDT(
        PurchaseData memory purchaseData
    ) public whenNotPaused nonReentrant returns (bool) {
        (
            uint256 currentStep,
            uint256 stagePrice,
            uint256 limiTokenAmount
        ) = getCurrentStage();
        require(
            stagePurcharsedToken + purchaseData.tokenAmount <= limiTokenAmount,
            "Presale: Wait next stage"
        );
        uint256 purchaseUSD = purchaseData.tokenAmount * stagePrice;
        (, bytes memory data) = usdt.staticcall(
            abi.encodeWithSignature(
                "allowance(address,address)",
                _msgSender(),
                address(this)
            )
        );
        uint256 allowance = abi.decode(data, (uint256));
        require(
            purchaseUSD <= allowance,
            "Presale: Make sure to add enough allowance"
        );
        (bool success, ) = usdt.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                _msgSender(),
                withdrawAddress,
                purchaseUSD * 10 ** 12
            )
        );
        require(success, "Presale: USDT payment is failed");
        update(
            purchaseUSD,
            purchaseData.tokenAmount,
            purchaseData.username,
            currentStep,
            1,
            DepositCurrency.USDT
        );
        emit BuyToken(
            purchaseData.username,
            _msgSender(),
            purchaseData.username,
            purchaseData.transactionId,
            currentStep,
            stagePrice,
            purchaseData.tokenAmount,
            1,
            DepositCurrency.USDT,
            block.timestamp
        );
        return true;
    }

    function buyWithCoin(
        PurchaseData memory purchaseData
    ) public payable whenNotPaused nonReentrant returns (bool) {
        (
            uint256 currentStep,
            uint256 stagePrice,
            uint256 limiTokenAmount
        ) = getCurrentStage();
        require(
            stagePurcharsedToken + purchaseData.tokenAmount <= limiTokenAmount,
            "Presale: Wait next stage"
        );
        uint256 purchaseUSD = purchaseData.tokenAmount * stagePrice;

        (uint256 ethAmount, uint256 coinPrice) = buyEthAmount(purchaseUSD);
        require(msg.value >= ethAmount, "Presale: Less ETH amount");
        sendValue(payable(owner()), ethAmount);
        update(
            purchaseUSD,
            purchaseData.tokenAmount,
            purchaseData.username,
            currentStep,
            coinPrice,
            DepositCurrency.COIN
        );
        emit BuyToken(
            purchaseData.username,
            _msgSender(),
            purchaseData.username,
            purchaseData.transactionId,
            currentStep,
            stagePrice,
            purchaseData.tokenAmount,
            coinPrice,
            DepositCurrency.COIN,
            block.timestamp
        );
        return true;
    }

    function updateOracle(address newOracle) public onlyOwner returns(bool) {
        require(oracle != newOracle, "Presale: Same address");
        oracle = newOracle;
        return true;
    }

    function updateWithdrawAddress(address newAddress) public onlyOwner returns(bool) {
        require(withdrawAddress != newAddress, "Presale: Same address");
        withdrawAddress = newAddress;
        return true;
    }

    function resetStage(uint256 step, uint256 startTime) public onlyOwner returns(bool) {
        (bool success, ) = oracle.call(
            abi.encodeWithSignature(
                "updateStage(uint256,uint256)",
                step,
                startTime
            )
        );
        require(success, "Presale: Reset is failed");
        stageStepTokens[step-1] = stagePurcharsedToken;
        stagePurcharsedToken = 0;
        return true;
    }

    function withdrawToken(
        address tokenAddress,
        uint256 tokenAmount
    ) public onlyOwner returns (bool) {
        (bool success, ) = tokenAddress.call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                _msgSender(),
                tokenAmount
            )
        );
        require(success, "Presale: Withdraw is failed");
        return true;
    }

    function withdrawEth() public onlyOwner returns (bool) {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "Presale: Withdraw is failed");
        return true;
    }

    function getCurrentStage() internal view returns (uint256, uint256, uint256) {
        (, bytes memory stepdata) = oracle.staticcall(
            abi.encodeWithSignature("getCurrentStage()")
        );
        uint256 currentStage = abi.decode(stepdata, (uint256));
        (, bytes memory stagedata) = oracle.staticcall(
            abi.encodeWithSignature("getStageInfo(uint256)", currentStage)
        );
        (uint256 stagePrice, uint256 limitTokenAmount) = abi.decode(
            stagedata,
            (uint256, uint256)
        );

        return (currentStage, stagePrice, limitTokenAmount);
    }

    function buyEthAmount(
        uint256 usdAmount
    ) internal view returns (uint256, uint256) {
        (, bytes memory data) = oracle.staticcall(
            abi.encodeWithSignature("getCoinPrice(address)", oraclePriceFeed)
        );
        uint256 coinPrice = abi.decode(data, (uint256));
        return ((usdAmount * 10 ** 2 * 10 ** 18) / coinPrice, coinPrice);
    }

    function update(
        uint256 _depositAmount,
        uint256 _tokenAmount,
        string memory _username,
        uint256 _step,
        uint256 _currencPrice,
        DepositCurrency _currency
    ) internal {
        userDeposits[_username].push(
            UserDeposit(
                _msgSender(),
                _depositAmount,
                _tokenAmount,
                _currency,
                _step,
                _currencPrice
            )
        );
        stagePurcharsedToken += _tokenAmount;
        totalPurcharsedToken += _tokenAmount;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Low balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "ETH Payment failed");
    }

    receive() external payable {}

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
