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
        USDC,
        CARD
    }
    enum TokenType {
        USDT,
        USDC
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
    address usdc;
    address withdrawAddress;
    address oraclePriceFeed;

    uint256 public MAX_PRESALE;
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
    event UpdateOracle(address prevOracle, address newOracle);
    event UpdateTokenAddress(TokenType tokenType, address prevTokenAddress, address newTokenAddress);
    event UpdateWithdrawAddress(address prevWithdrawAddress, address newWithdrawAddress);
    event ResetStage(uint256 prevStepDealAmount, uint256 step, uint256 startTime);
    event Withdraw(address tokenAddress, uint256 amount, address to);

    function initialize(
        address initialOwner,
        address _oracle,
        address _usdt,
        address _usdc,
        address _oraclePriceFeed
    ) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        oracle = _oracle;
        usdt = _usdt;
        usdc = _usdc;
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
    function buyWithToken(
        DepositCurrency tokenType,
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
        address tokenAddress = tokenType == DepositCurrency.USDT ? usdt : usdc;
        (, bytes memory data) = tokenAddress.staticcall(
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
        (bool success, ) = tokenAddress.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                _msgSender(),
                withdrawAddress,
                purchaseUSD * 10 ** 12
            )
        );
        require(success, "Presale: Token payment is failed");
        update(
            purchaseUSD,
            purchaseData.tokenAmount,
            purchaseData.username,
            currentStep,
            1,
            tokenType
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
            tokenType,
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
        sendValue(payable(withdrawAddress), ethAmount);
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

    function BuyWithCard(PurchaseData memory purchaseData) public onlyOwner returns(bool) {
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
        
        update(
            purchaseUSD,
            purchaseData.tokenAmount,
            purchaseData.username,
            currentStep,
            1,
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
            1,
            DepositCurrency.CARD,
            block.timestamp
        );
        return true;
    }

    function updateOracle(address newOracle) public onlyOwner returns(bool) {
        require(oracle != newOracle, "Presale: Same address");
        address prevOracle = oracle;
        oracle = newOracle;
        emit UpdateOracle(prevOracle, newOracle);
        return true;
    }

    function updateTokenAddress(TokenType tokenType, address newAddress) public onlyOwner returns(bool) {
        require(usdt != newAddress && usdc != newAddress, "Presale: Same address");
        address prevAddress = tokenType == TokenType.USDT ? usdt : usdc;
        if(tokenType == TokenType.USDT) {
            usdt = newAddress;
        } else {
            usdc = newAddress;
        }

        emit UpdateTokenAddress(tokenType, prevAddress, newAddress);
        return true;
    }

    function updateWithdrawAddress(address newAddress) public onlyOwner returns(bool) {
        require(withdrawAddress != newAddress, "Presale: Same address");
        address prevWithdrawAddress = withdrawAddress;
        withdrawAddress = newAddress;
        emit UpdateWithdrawAddress(prevWithdrawAddress, newAddress);
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
        uint256 prevStageDealAmount = stagePurcharsedToken;
        stagePurcharsedToken = 0;

        emit ResetStage(prevStageDealAmount, step, startTime);
        return true;
    }

    function withdrawToken(
        address tokenAddress,
        uint256 tokenAmount
    ) public onlyOwner returns (bool) {
        (bool success, ) = tokenAddress.call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                withdrawAddress,
                tokenAmount
            )
        );
        require(success, "Presale: Withdraw is failed");
        
        emit Withdraw(tokenAddress, tokenAmount, withdrawAddress);
        return true;
    }

    function withdrawEth() public onlyOwner returns (bool) {
        (bool success, ) = withdrawAddress.call{value: address(this).balance}("");
        require(success, "Presale: Withdraw is failed");

        emit Withdraw(address(0), address(this).balance, withdrawAddress);
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

        require(currentStage != 0 && stagePrice != 0, "Presale: Stage didn't start");

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
