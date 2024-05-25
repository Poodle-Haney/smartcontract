// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PoodleHaney is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    OwnableUpgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable
{
    uint256 public teamPercent;
    uint256 public revenuePercent;
    uint256 public burnPercent;
    address public teamWallet;
    address public revenueWallet;

    mapping(address => bool) public isBlacklisted;
    mapping(address => bool) public isExecuteWallet;

    function initialize(address initialOwner, address _teamWallet, address _revenueWallet) public initializer {
        __ERC20_init("PoodleHaney", "HANEY");
        __ERC20Burnable_init();
        __ERC20Pausable_init();
        __Ownable_init(initialOwner);
        __ERC20Permit_init("PoodleHaney");
        __UUPSUpgradeable_init();
        teamWallet = _teamWallet;
        revenueWallet = _revenueWallet;
        teamPercent = 100;
        revenuePercent = 200;
        burnPercent = 100;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function changeRevenueWallet(address newWallet) public onlyOwner {
        require(revenueWallet != newWallet, "HANEY: Same wallet address");
        revenueWallet = newWallet;
    }

    function changeTeamWallet(address newWallet) public onlyOwner {
        require(teamWallet != newWallet, "HANEY: Same wallet address");
        teamWallet = newWallet;
    }

    function addExecuteWallet(address wallet) external onlyOwner {
        isExecuteWallet[wallet] = true;
    }

    function removeExecuteWallet(address wallet) external onlyOwner {
        isExecuteWallet[wallet] = false;
    }

    function blacklistAddress(address account) external onlyOwner {
        isBlacklisted[account] = true;
    }

    function removeBlacklist(address account) external onlyOwner {
        isBlacklisted[account] = false;
    }

    function _transfer(address from, address to, uint256 value) internal override {
        require(!isBlacklisted[from], "HANEY: Sender is blacklisted");
        require(!isBlacklisted[to], "HANEY: Recipient is blacklisted");

        if (isExecuteWallet[from]) {
            super._transfer(from, to, value);
            return;
        }

        uint256 teamFee = value * teamPercent / 10000;
        uint256 revenueFee = value * revenuePercent /10000;
        uint256 burnFee = value * burnPercent / 10000;
        uint256 amountAfterFee = value - (teamFee + revenueFee + burnFee);
        super._transfer(from, to, amountAfterFee);
        if (teamFee > 0) {
            super._transfer(from, teamWallet, teamFee);
        }
        if (revenueFee > 0) {
            super._transfer(from, revenueWallet, revenueFee);
        }
        if (burnFee > 0) {
            _burn(from, burnFee);
        }
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) {
        super._update(from, to, value);
    }
}
