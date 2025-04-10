// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title MentoraToken
 * @dev ERC20 token for the Mentora platform that enables rewards, purchases, and incentives
 */
contract MentoraToken is ERC20, Ownable, Pausable, AccessControl {
    bytes32 public constant REWARDER_ROLE = keccak256("REWARDER_ROLE");
    uint256 public coursePurchaseReward;
    uint256 public courseCompletionReward;
    uint256 public contentCreationReward;
    uint256 public assignmentCompletionReward;
    
    // Events
    event TokensRewarded(address indexed user, uint256 amount, string reason);
    event RewardRateUpdated(string rewardType, uint256 newAmount);
    
    constructor(uint256 _initialSupply, uint256 _coursePurchaseReward, uint256 _courseCompletionReward, uint256 _contentCreationReward, uint256 _assignmentCompletionReward) ERC20("MentoraToken", "MTK") Ownable(msg.sender) {
        _mint(msg.sender, _initialSupply);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REWARDER_ROLE, msg.sender);
        coursePurchaseReward = _coursePurchaseReward;
        courseCompletionReward = _courseCompletionReward;
        contentCreationReward = _contentCreationReward;
        assignmentCompletionReward = _assignmentCompletionReward;
    }
    
    /**
     * @dev Rewards tokens to users for various activities
     * @param _user Address of the user to reward
     * @param _amount Amount of tokens to reward
     * @param _reason Reason for the reward
     */
    function rewardUser(address _user, uint256 _amount, string memory _reason) external onlyRole(REWARDER_ROLE) whenNotPaused {
        require(_user != address(0), "Invalid user address");
        require(_amount > 0, "Reward amount must be greater than zero");
        
        _mint(_user, _amount);
        emit TokensRewarded(_user, _amount, _reason);
    }
    
    /**
     * @dev Rewards tokens for purchasing a course
     * @param _user Address of the user who purchased a course
     */
    function rewardCoursePurchase(address _user) external onlyRole(REWARDER_ROLE) whenNotPaused {
        require(_user != address(0), "Invalid user address");
        
        _mint(_user, coursePurchaseReward);
        emit TokensRewarded(_user, coursePurchaseReward, "Course Purchase");
    }
    
    /**
     * @dev Rewards tokens for completing a course
     * @param _user Address of the user who completed a course
     */
    function rewardCourseCompletion(address _user) external onlyRole(REWARDER_ROLE) whenNotPaused {
        require(_user != address(0), "Invalid user address");
        
        _mint(_user, courseCompletionReward);
        emit TokensRewarded(_user, courseCompletionReward, "Course Completion");
    }
    
    /**
     * @dev Rewards tokens for creating content
     * @param _creator Address of the content creator
     */
    function rewardContentCreation(address _creator) external onlyRole(REWARDER_ROLE) whenNotPaused {
        require(_creator != address(0), "Invalid creator address");
        
        _mint(_creator, contentCreationReward);
        emit TokensRewarded(_creator, contentCreationReward, "Content Creation");
    }

    /**
     * @dev Rewards tokens for completing an assignment
     * @param _student Address of the student who completed the assignment
     */
    function rewardAssignmentCompletion(address _student) external onlyRole(REWARDER_ROLE) whenNotPaused {
        require(_student != address(0), "Invalid student address");
        
        _mint(_student, assignmentCompletionReward);
        emit TokensRewarded(_student, assignmentCompletionReward, "Assignment Completion");
    }
    
    /**
     * @dev Updates reward rates
     * @param _purchaseReward New reward for course purchases
     * @param _completionReward New reward for course completions
     * @param _creationReward New reward for content creation
     * @param _assignmentReward New reward for assignment completion
     */
    function updateRewardRates(
        uint256 _purchaseReward,
        uint256 _completionReward,
        uint256 _creationReward,
        uint256 _assignmentReward
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        coursePurchaseReward = _purchaseReward;
        courseCompletionReward = _completionReward;
        contentCreationReward = _creationReward;
        assignmentCompletionReward = _assignmentReward;
        
        emit RewardRateUpdated("Purchase", _purchaseReward);
        emit RewardRateUpdated("Completion", _completionReward);
        emit RewardRateUpdated("Creation", _creationReward);
        emit RewardRateUpdated("Assignment", _assignmentReward);
    }
    
    /**
     * @dev Burns tokens from the caller's account
     * @param _amount Amount of tokens to burn
     */
    function burn(uint256 _amount) external whenNotPaused {
        require(_amount > 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) >= _amount, "Insufficient balance");
        
        _burn(msg.sender, _amount);
    }

    /**
     * @dev Pauses all token transfers and rewards
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers and rewards
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Override to add pausable functionality
     */
    function _update(address from, address to, uint256 value)
        internal
        virtual
        override
        whenNotPaused
    {
        super._update(from, to, value);
    }
}