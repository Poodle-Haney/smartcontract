// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

contract PoodleHaney is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    OwnableUpgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable
{
    enum FeeType {
        COIN,
        TOKEN
    }
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    uint256 private maxSupply;
    bool private swapping;
    uint256 public swapTokensAtAmount;

    uint256 public teamPercent;
    uint256 public revenuePercent;
    uint256 public liquidityPercent;

    address public teamWallet;
    address public revenueWallet;

    bool public swapEnabled;
    uint256 private tokensForRevShare;
    uint256 private tokensForLiquidity;
    uint256 private tokensForTeam;

    FeeType public feeType;

    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public isExecuteWallet;
    mapping(address => bool) public automatedMarketMakerPairs;

    event ChangeFeeWallet(
        address indexed oldWallet,
        address indexed newWallet,
        string walletType
    );
    event ExcludeWallet(address indexed account, bool value);
    event UpdateUniswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    event ChangeFeeType(FeeType oldType, FeeType newType);

    function initialize(
        address initialOwner,
        address _uniswapV2Router,
        address _teamWallet,
        address _revenueWallet
    ) public initializer {
        __ERC20_init("PoodleHaney", "HANEY");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __Ownable_init(initialOwner);
        __ERC20Permit_init("PoodleHaney");
        __UUPSUpgradeable_init();

        updateUniswapV2Router(_uniswapV2Router);
        teamWallet = _teamWallet;
        revenueWallet = _revenueWallet;
        teamPercent = 100;
        revenuePercent = 200;
        liquidityPercent = 100;
        swapEnabled = false;
        isExecuteWallet[initialOwner] = true;
        feeType = FeeType.TOKEN;

        maxSupply = 1 * 10 ** 11 * (10 ** uint256(decimals()));
        swapTokensAtAmount = (maxSupply * 5) / 10000; // 0.05%
        _mint(initialOwner, maxSupply);
        transferOwnership(initialOwner);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function enableTrading() external onlyOwner {
        swapEnabled = true;
    }

    function updateUniswapV2Router(address newAddress) public onlyOwner {
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                uniswapV2Router.WETH()
            );
    }

    function changeFeeType(FeeType _type) external onlyOwner {
        emit ChangeFeeType(feeType, _type);
        feeType = _type;
    }

    function changeRevenueWallet(address newWallet) external onlyOwner {
        require(revenueWallet != newWallet, "Same wallet address");
        emit ChangeFeeWallet(revenueWallet, newWallet, "revenueWallet");
        revenueWallet = newWallet;
    }

    function changeTeamWallet(address newWallet) external onlyOwner {
        require(teamWallet != newWallet, "Same wallet address");
        emit ChangeFeeWallet(teamWallet, newWallet, "teamWallet");
        teamWallet = newWallet;
    }

    function setExcludeWallet(address wallet, bool value) external onlyOwner {
        isExecuteWallet[wallet] = value;
        emit ExcludeWallet(wallet, value);
    }

    function blacklistAddress(address account) external onlyOwner {
        require(!isBlacklisted[account], "Already blacklisted");
        isBlacklisted[account] = true;
    }

    function removeBlacklist(address account) external onlyOwner {
        require(isBlacklisted[account], "Not blacklisted");
        isBlacklisted[account] = false;
    }

    function changeFees(
        uint256 _revenuePercent,
        uint256 _teamPercent,
        uint256 _liquidityPercent
    ) external onlyOwner {
        revenuePercent = _revenuePercent;
        teamPercent = _teamPercent;
        liquidityPercent = _liquidityPercent;
        require(
            _revenuePercent + _teamPercent + _liquidityPercent <= 400,
            "Total fee must not exceed 400"
        );
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        require(!isBlacklisted[from], "Sender is blacklisted");
        require(!isBlacklisted[to], "Recipient is blacklisted");

        if (
            isExecuteWallet[from] ||
            isExecuteWallet[to] ||
            from == address(0) ||
            to == address(0)
        ) {
            super._update(from, to, value);
            return;
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if (
            canSwap &&
            swapEnabled &&
            !swapping &&
            !automatedMarketMakerPairs[from]
        ) {
            swapping = true;
            if (feeType == FeeType.COIN) {
                swapBack();
            } else {
                swapAndLiquify();
            }
            swapping = false;
        }

        bool takeFee = !swapping &&
            !isExecuteWallet[from] &&
            !isExecuteWallet[to];

        uint256 fees = 0;
        if (takeFee) {
            uint256 teamFee = (value * teamPercent) / 10000;
            uint256 liquidityFee = (value * liquidityPercent) / 10000;
            uint256 revenueFee = (value * revenuePercent) / 10000;
            fees = teamFee + liquidityFee + revenueFee;
            if (feeType == FeeType.COIN) {
                tokensForLiquidity += liquidityFee;
                tokensForTeam += teamFee;
                tokensForRevShare += revenueFee;
                if (fees > 0) {
                    super._update(from, address(this), fees);
                }
            } else {
                if (teamFee > 0) super._update(from, teamWallet, teamFee);
                if (liquidityFee > 0)
                    super._update(from, address(this), liquidityFee);
                if (revenueFee > 0)
                    super._update(from, revenueWallet, revenueFee);
            }
        }

        super._update(from, to, value - fees);
    }

    function swapAndLiquify() private {
        uint256 half = tokensForLiquidity / 2;
        uint256 otherHalf = tokensForLiquidity - half;
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(half);
        uint256 newBalance = address(this).balance - initialBalance;
        addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquify(half, newBalance, otherHalf);
        tokensForLiquidity = 0;
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            address(0),
            block.timestamp
        );
    }

    function swapBack() private {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = tokensForLiquidity +
            tokensForRevShare +
            tokensForTeam;
        if (contractBalance == 0 || totalTokensToSwap == 0) return;
        if (contractBalance > swapTokensAtAmount * 20)
            contractBalance = swapTokensAtAmount * 20;
        uint256 liquidityTokens = (contractBalance * tokensForLiquidity) /
            totalTokensToSwap /
            2;
        uint256 amountToSwapForETH = contractBalance - liquidityTokens;
        uint256 initialETHBalance = address(this).balance;
        swapTokensForEth(amountToSwapForETH);
        uint256 ethBalance = address(this).balance - initialETHBalance;
        uint256 ethForRevShare = (ethBalance * tokensForRevShare) /
            (totalTokensToSwap - (tokensForLiquidity / 2));
        uint256 ethForTeam = (ethBalance * tokensForTeam) /
            (totalTokensToSwap - (tokensForLiquidity / 2));
        uint256 ethForLiquidity = ethBalance - ethForRevShare - ethForTeam;
        tokensForLiquidity = 0;
        tokensForRevShare = 0;
        tokensForTeam = 0;
        (bool success, ) = address(teamWallet).call{value: ethForTeam}("");
        if (liquidityTokens > 0 && ethForLiquidity > 0)
            addLiquidity(liquidityTokens, ethForLiquidity);
        emit SwapAndLiquify(
            amountToSwapForETH,
            ethForLiquidity,
            tokensForLiquidity
        );
        (success, ) = address(revenueWallet).call{value: address(this).balance}(
            ""
        );
    }

    receive() external payable {}
}
