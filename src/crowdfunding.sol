// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract SimpleCrowdfunding is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public goal;
    uint256 public deadline;
    uint256 public totalRaised;
    bool public fundsWithdrawn;

    mapping(address => uint256) public contributions;

    event Contributed(address indexed user, uint256 amount);
    event GoalReached(uint256 totalAmount);
    event RefundClaimed(address indexed user, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 _goal, uint256 _durationInDays) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        goal = _goal;
        deadline = block.timestamp + (_durationInDays * 1 days);
    }

    // Allow users to send ETH
    function contribute() external payable {
        require(block.timestamp < deadline, "Funding period has ended");
        require(msg.value > 0, "Must contribute some ETH");

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit Contributed(msg.sender, msg.value);
    }

    // Owner withdraws if goal is met
    function withdrawFunds() external onlyOwner {
        require(totalRaised >= goal, "Goal not reached");
        require(block.timestamp >= deadline, "Deadline not yet passed");
        require(!fundsWithdrawn, "Funds already withdrawn");

        fundsWithdrawn = true;
        (bool success, ) = payable(owner()).call{value: totalRaised}("");
        require(success, "Transfer failed");
    }

    // Contributors claim refunds if goal is missed
    function claimRefund() external {
        require(block.timestamp >= deadline, "Deadline not yet passed");
        require(totalRaised < goal, "Goal was reached");
        
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No contribution to refund");

        // Prevent double refunds by zeroing balance BEFORE transfer
        contributions[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");

        emit RefundClaimed(msg.sender, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}