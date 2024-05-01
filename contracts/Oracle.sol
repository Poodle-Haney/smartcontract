//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

contract Oracle is
    Initializable,
    OwnableUpgradeable,
    AccessControlEnumerableUpgradeable,
    UUPSUpgradeable
{
    struct StageInfo {
        uint256 price;
        uint256 limitTokenAmount;
        uint256 minDealUSD;
        uint256 startTime;
        uint256 endTime;
    }

    bytes32 public CHANGE_STAGE_ROLE;

    uint256 currentStage;
    mapping(uint256 => StageInfo) stages;

    event AddStage(uint256 indexed step, StageInfo info);
    event Remove(uint256 indexed step);

    // constructor() {
    //     _disableInitializers();
    // }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        currentStage = 1;
        CHANGE_STAGE_ROLE = keccak256("CHANGE_STAGE_ROLE");
        _grantRole(CHANGE_STAGE_ROLE, _msgSender());
    }

    function addStages(
        uint256[] memory steps,
        StageInfo[] memory stageInfos
    ) public onlyOwner {
        require(
            steps.length == stageInfos.length,
            "Oracle: Wrong stage length"
        );
        for (uint8 i = 0; i < steps.length; i++) {
            stages[steps[i]] = stageInfos[i];
        }
    }

    function addStage(
        uint256 step,
        StageInfo memory stageInfo
    ) public onlyOwner {
        // require(!stages[step], "Oracle: Duplicated stage");
        stages[step] = stageInfo;
    }

    function removeStages(uint256[] memory steps) public onlyOwner {
        for (uint8 i; i < steps.length; i++) {
            delete stages[steps[i]];
        }
    }

    function updateChangeStageRole(address newRole) public onlyOwner {
        _grantRole(CHANGE_STAGE_ROLE, newRole);
    }

    function updateStage(uint256 step) public {
        require(
            hasRole(CHANGE_STAGE_ROLE, _msgSender()),
            "Oracle: Must be CHANGE_STAGE_ROLE role"
        );
        require(step > currentStage, "Oracle: Already activated");
        currentStage = step;
    }

    function getCurrentStage() public view returns (uint256) {
        return currentStage;
    }

    function getStageInfo(
        uint256 step
    ) public view returns (uint256 stagePrice, uint256 limitTokenAmount) {
        StageInfo memory stage = stages[step];
        stagePrice = stage.price;
        limitTokenAmount = stage.limitTokenAmount;
    }

    function getCoinPrice(address feed) public view returns (int256) {
        (, bytes memory data) = feed.staticcall(
            abi.encodeWithSignature("latestRoundData()")
        );
        (, int256 price, , , ) = abi.decode(
            data,
            (uint80, int256, uint256, uint256, uint80)
        );
        return price;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
