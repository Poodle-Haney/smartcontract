/******************************************************************************************************/
/*                                                                                                    */
/*  ██████╗  ██████╗  ██████╗ ██████╗ ██╗     ███████╗    ██╗  ██╗ █████╗ ███╗   ██╗███████╗██╗   ██╗ */
/*  ██╔══██╗██╔═══██╗██╔═══██╗██╔══██╗██║     ██╔════╝    ██║  ██║██╔══██╗████╗  ██║██╔════╝╚██╗ ██╔╝ */
/*  ██████╔╝██║   ██║██║   ██║██║  ██║██║     █████╗      ███████║███████║██╔██╗ ██║█████╗   ╚████╔╝  */
/*  ██╔═══╝ ██║   ██║██║   ██║██║  ██║██║     ██╔══╝      ██╔══██║██╔══██║██║╚██╗██║██╔══╝    ╚██╔╝   */
/*  ██║     ╚██████╔╝╚██████╔╝██████╔╝███████╗███████╗    ██║  ██║██║  ██║██║ ╚████║███████╗   ██║    */
/*  ╚═╝      ╚═════╝  ╚═════╝ ╚═════╝ ╚══════╝╚══════╝    ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝    */
/*                                                                                                    */
/******************************************************************************************************/

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
    }

    bytes32 public CHANGE_STAGE_ROLE;

    uint256 public priceDecimal;
    uint256 currentStage;
    uint256 stageDuration;
    uint256 stageStepDuration;
    uint256 stageStartTime;
    mapping(uint256 => StageInfo) stages;

    event AddStage(uint256 indexed step, StageInfo info);
    event Remove(uint256 indexed step);
    event StartStage(uint256 stage, uint256 startTime);
    event ChangeStageStepDuration(uint256 prevDuration, uint256 nowDuration);

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        CHANGE_STAGE_ROLE = keccak256("CHANGE_STAGE_ROLE");
        _grantRole(CHANGE_STAGE_ROLE, _msgSender());
        stageStepDuration = 30 minutes;
        priceDecimal = 7;
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
            emit AddStage(steps[i], stageInfos[i]);
        }
    }

    function addStage(
        uint256 step,
        StageInfo memory stageInfo
    ) public onlyOwner {
        // require(!stages[step], "Oracle: Duplicated stage");
        stages[step] = stageInfo;
        emit AddStage(step, stageInfo);
    }

    function startStage(uint256 startTime) public onlyOwner returns (uint256) {
        // require(currentStage == 0, "Oracle: Alrady started stage");
        currentStage = 1;
        stageStartTime = startTime;
        return stageStartTime;
    }

    function removeStages(uint256[] memory steps) public onlyOwner {
        for (uint8 i; i < steps.length; i++) {
            delete stages[steps[i]];
            emit Remove(steps[i]);
        }
    }

    function updateChangeStageRole(address newRole) public onlyOwner {
        _grantRole(CHANGE_STAGE_ROLE, newRole);
    }

    function updateStage(uint256 step, uint256 startTime) public {
        require(
            hasRole(CHANGE_STAGE_ROLE, _msgSender()),
            "Oracle: Must be CHANGE_STAGE_ROLE role"
        );
        require(step > currentStage, "Oracle: Already activated");
        currentStage = step;
        stageStartTime = startTime;
        emit StartStage(step, startTime);
    }

    function updateStageDuration(uint256 duration) public returns (bool) {
        require(
            hasRole(CHANGE_STAGE_ROLE, _msgSender()),
            "Oracle: Must be CHANGE_STAGE_ROLE role"
        );
        uint256 prevDuration = stageStepDuration;
        stageStepDuration = duration;

        emit ChangeStageStepDuration(prevDuration, duration);
        return true;
    }

    function getCurrentStage() public view returns (uint256) {
        return currentStage;
    }

    function getStageInfo(
        uint256 step
    ) public view returns (uint256 stagePrice, uint256 limitTokenAmount) {
        StageInfo memory stage = stages[step];
        (stagePrice, ) = calculatePrice();
        limitTokenAmount = stage.limitTokenAmount;
    }

    function getCurrentStageInfo()
        public
        view
        returns (
            uint256 stageStep,
            uint256 price,
            uint256 limitTokenAmount,
            uint256 minDealUSD,
            uint256 endTime
        )
    {
        stageStep = currentStage;
        StageInfo memory info = stages[currentStage];
        (price, endTime) = calculatePrice();
        limitTokenAmount = info.limitTokenAmount;
        minDealUSD = info.minDealUSD;
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

    function calculatePrice() internal view returns (uint256, uint256) {
        if (block.timestamp <= stageStartTime || stageStartTime == 0) {
            return (0, stageStartTime);
        }
        uint256 stageStep = (block.timestamp - stageStartTime) /
            stageStepDuration;
        StageInfo memory currentStageInfo = stages[currentStage];
        StageInfo memory nextStage = stages[currentStage + 1];
        uint256 stepPrice = currentStageInfo.price + stageStep >=
            nextStage.price
            ? nextStage.price - 1
            : currentStageInfo.price + stageStep;
        uint256 endTime = stageStartTime + (stageStep + 1) * stageStepDuration;
        return (stepPrice, endTime);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
