// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MentoraToken} from "./MentoraToken.sol";

/**
 * @title CourseMarketplace
 * @dev Smart contract for managing and selling educational courses on blockchain with IPFS content storage
 */
contract CourseManager is Ownable, Pausable, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public courseCounter;
    uint256 public platformFeePercent;
    
    struct CourseContent {
        string contentIpfsHash; // JSON containing intro video, modules, materials
        uint256 materialCount;
    }
    
    struct Course {
        uint256 id;
        string title;
        string description;
        string category;
        uint256 difficulty;
        string thumbnailIpfsHash;
        address creator;
        uint256 price;
        bool isActive;
        uint256 totalSales;
        uint256 totalRevenue;
        uint256 moduleCount;
        uint256 enrolledUsers;
        uint256 duration; // Duration in minutes
    }
    
    struct Purchase {
        uint256 courseId;
        uint256 purchaseDate;
        bool refundRequested;
        bool refunded;
        bool completed;
        uint256 completedDate;
    }

    bytes32 public constant INSTRUCTOR_ROLE = keccak256("INSTRUCTOR_ROLE");
    bytes32 public constant STUDENT_ROLE = keccak256("STUDENT_ROLE");

    
    // MentoraToken instance
    MentoraToken private mentoraToken;
    
    // Mapping to store courses by their ID
    mapping(uint256 => Course) public courses;
    mapping(uint256 => CourseContent) private courseContents;
    mapping(address => mapping(uint256 => Purchase)) public userPurchases;
    mapping(address => uint256[]) public userCourseIds;
    mapping(address => uint256[]) public creatorCourseIds;
    mapping(address => uint256) public creatorBalance;
    
    // Events
    event CourseCreated(uint256 courseId, string title, address creator, uint256 price);
    event CoursePurchased(uint256 courseId, address buyer, uint256 price);
    event CourseUpdated(uint256 courseId, string title, uint256 price, bool isActive);
    event CourseDelisted(uint256 courseId);
    event CourseContentUpdated(uint256 courseId, uint256 moduleCount);
    event ModuleAdded(uint256 courseId, uint256 moduleIndex, string moduleTitle);
    event MaterialAdded(uint256 courseId, uint256 moduleIndex, uint256 materialIndex);
    event RefundRequested(uint256 courseId, address buyer);
    event RefundProcessed(uint256 courseId, address buyer, uint256 amount);
    event CreatorWithdrawal(address creator, uint256 amount);
    event CourseCompleted(uint256 courseId, address student, uint256 completedDate);
    event TokensRewarded(address student, uint256 courseId, uint256 amount);
    
    // Modifiers    
    modifier onlyCourseCreator(uint256 _courseId) {
        require(courses[_courseId].creator == msg.sender, "Only course creator can modify this course");
        _;
    }
    
    modifier courseExists(uint256 _courseId) {
        require(_courseId > 0 && _courseId <= courseCounter, "Course does not exist");
        _;
    }
    
    modifier courseActive(uint256 _courseId) {
        require(courses[_courseId].isActive, "Course is not active");
        _;
    }
    
    modifier hasPurchasedCourse(uint256 _courseId) {
        require(userPurchases[msg.sender][_courseId].purchaseDate > 0 && !userPurchases[msg.sender][_courseId].refunded, 
            "You have not purchased this course");
        _;
    }

    modifier hasNotCompletedCourse(uint256 _courseId) {
        require(!userPurchases[msg.sender][_courseId].completed, "Course already completed");
        _;
    }
    
    constructor(uint256 _platformFeePercent, address _mentoraToken) Ownable(msg.sender) {
        require(_platformFeePercent <= 30, "Fee cannot exceed 30%");
        courseCounter = 0;
        platformFeePercent = _platformFeePercent;
        mentoraToken = MentoraToken(_mentoraToken);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(INSTRUCTOR_ROLE, msg.sender);
    }
    
    /**
     * @dev Create a new course
     * @param _title Course title
     * @param _description Course description
     * @param _thumbnailIpfsHash IPFS hash of the course thumbnail
     * @param _contentIpfsHash IPFS hash of the course content JSON
     * @param _price Course price in wei
     */
    function createCourse(
        string calldata _title,
        string calldata _description,
        string calldata _category,
        string calldata _thumbnailIpfsHash,
        string calldata _contentIpfsHash,
        uint256 _difficulty,
        uint256 _duration,
        uint256 _price,
        uint256 _moduleCount
    ) external whenNotPaused nonReentrant {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_thumbnailIpfsHash).length > 0, "Thumbnail IPFS hash cannot be empty");
        require(bytes(_contentIpfsHash).length > 0, "Content IPFS hash cannot be empty");
        require(_price > 0, "Price must be greater than zero");
        
        courseCounter++;
        
        // Create new course
        Course storage newCourse = courses[courseCounter];
        newCourse.id = courseCounter;
        newCourse.title = _title;
        newCourse.description = _description;
        newCourse.category = _category;
        newCourse.thumbnailIpfsHash = _thumbnailIpfsHash;
        newCourse.difficulty = _difficulty;
        newCourse.creator = msg.sender;
        newCourse.price = _price;
        newCourse.isActive = true;
        newCourse.totalSales = 0;
        newCourse.totalRevenue = 0;
        newCourse.moduleCount = _moduleCount;
        newCourse.enrolledUsers = 0;
        newCourse.duration = _duration;
        
        // Initialize course content
        CourseContent storage newContent = courseContents[courseCounter];
        newContent.contentIpfsHash = _contentIpfsHash;
        newContent.materialCount = 0;
        
        creatorCourseIds[msg.sender].push(courseCounter);

        // Reward creator for content creation
        // if (address(mentoraToken) != address(0)) {
        //     mentoraToken.rewardContentCreation(msg.sender);
        // }
        
        emit CourseCreated(courseCounter, _title, msg.sender, _price);
    }
    
    /**
     * @dev Update course content
     * @param _courseId ID of the course
     * @param _contentIpfsHash New IPFS hash for the content JSON
     * @param _moduleCount Updated module count
     */
    function updateCourseContent(
        uint256 _courseId,
        string calldata _contentIpfsHash,
        uint256 _moduleCount
    ) 
        external 
        courseExists(_courseId)
        onlyCourseCreator(_courseId)
        whenNotPaused
        nonReentrant
    {
        require(bytes(_contentIpfsHash).length > 0, "Content IPFS hash cannot be empty");
        
        Course storage course = courses[_courseId];
        CourseContent storage content = courseContents[_courseId];
        
        // Update content hash
        content.contentIpfsHash = _contentIpfsHash;
        
        // Update course module count
        course.moduleCount = _moduleCount;
        
        emit CourseContentUpdated(_courseId, _moduleCount);
    }
    
    /**
     * @dev Update material count
     * @param _courseId ID of the course
     * @param _materialCount New material count
     */
    function updateMaterialCount(
        uint256 _courseId,
        uint256 _materialCount
    )
        external
        courseExists(_courseId)
        onlyCourseCreator(_courseId)
        whenNotPaused
        nonReentrant
    {
        CourseContent storage content = courseContents[_courseId];
        content.materialCount = _materialCount;
    }
    
    /**
     * @dev Update course details
     * @param _courseId ID of the course to update
     * @param _title New course title
     * @param _description New course description
     * @param _thumbnailIpfsHash New thumbnail IPFS hash
     * @param _contentIpfsHash New content IPFS hash
     * @param _price New course price in wei
     * @param _isActive Course active status
     */
    function updateCourse(
        uint256 _courseId, 
        string calldata _title, 
        string calldata _description,
        string calldata _thumbnailIpfsHash,
        string calldata _contentIpfsHash,
        uint256 _price, 
        bool _isActive,
        uint256 _moduleCount
    ) 
        external 
        courseExists(_courseId) 
        onlyCourseCreator(_courseId)
        whenNotPaused
        nonReentrant
    {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_thumbnailIpfsHash).length > 0, "Thumbnail IPFS hash cannot be empty");
        require(bytes(_contentIpfsHash).length > 0, "Content IPFS hash cannot be empty");
        require(_price > 0, "Price must be greater than zero");
        
        Course storage course = courses[_courseId];
        course.title = _title;
        course.description = _description;
        course.thumbnailIpfsHash = _thumbnailIpfsHash;
        course.price = _price;
        course.isActive = _isActive;
        course.moduleCount = _moduleCount;
        
        CourseContent storage content = courseContents[_courseId];
        content.contentIpfsHash = _contentIpfsHash;
        
        emit CourseUpdated(_courseId, _title, _price, _isActive);
    }
    
    /**
     * @dev Delist a course
     * @param _courseId ID of the course to delist
     */
    function delistCourse(uint256 _courseId) 
        external 
        courseExists(_courseId) 
        onlyCourseCreator(_courseId)
        whenNotPaused
        nonReentrant
    {
        courses[_courseId].isActive = false;
        emit CourseDelisted(_courseId);
    }
    
    /**
     * @dev Purchase a course
     * @param _courseId ID of the course to purchase
     */
    function purchaseCourse(uint256 _courseId) 
        external 
        payable 
        courseExists(_courseId)
        courseActive(_courseId)
        whenNotPaused
        nonReentrant
    {
        Course storage course = courses[_courseId];
        require(msg.value >= course.price, "Insufficient payment");
        require(userPurchases[msg.sender][_courseId].purchaseDate == 0, "Course already purchased");
        
        // Calculate platform fee
        uint256 platformFee = (course.price * platformFeePercent) / 100;
        uint256 creatorAmount = course.price - platformFee;
        
        // Update course statistics
        course.totalSales++;
        course.totalRevenue += course.price;
        course.enrolledUsers++;
        
        // Update creator balance
        creatorBalance[course.creator] += creatorAmount;
        
        // Record purchase
        userPurchases[msg.sender][_courseId] = Purchase({
            courseId: _courseId,
            purchaseDate: block.timestamp,
            refundRequested: false,
            refunded: false,
            completed: false,
            completedDate: 0
        });
        
        userCourseIds[msg.sender].push(_courseId);
        
        // Refund excess payment
        if (msg.value > course.price) {
            payable(msg.sender).transfer(msg.value - course.price);
        }

        // Reward token for course purchase
        if (address(mentoraToken) != address(0)) {
            mentoraToken.rewardCoursePurchase(msg.sender);
        }
        
        emit CoursePurchased(_courseId, msg.sender, course.price);
    }

    /**
     * @dev Mark a course as completed by the student
     * @param _courseId ID of the course to mark as completed
     */
    function completeCourse(uint256 _courseId) 
        external 
        courseExists(_courseId)
        hasPurchasedCourse(_courseId)
        hasNotCompletedCourse(_courseId)
        whenNotPaused
        nonReentrant
    {
        Purchase storage purchase = userPurchases[msg.sender][_courseId];
        
        purchase.completed = true;
        purchase.completedDate = block.timestamp;
        
        // Reward token for course completion
        if (address(mentoraToken) != address(0)) {
            mentoraToken.rewardCourseCompletion(msg.sender);
            emit TokensRewarded(msg.sender, _courseId, mentoraToken.courseCompletionReward());
        }
        
        emit CourseCompleted(_courseId, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Request a refund for a purchased course
     * @param _courseId ID of the course for refund
     */
    function requestRefund(uint256 _courseId) 
        external 
        courseExists(_courseId)
        whenNotPaused
        nonReentrant
    {
        Purchase storage purchase = userPurchases[msg.sender][_courseId];
        require(purchase.purchaseDate > 0, "Course not purchased");
        require(!purchase.refundRequested, "Refund already requested");
        require(!purchase.refunded, "Already refunded");
        require(!purchase.completed, "Cannot refund completed course");
        
        // Check if within refund period (30 days)
        require(block.timestamp <= purchase.purchaseDate + 30 days, "Refund period expired");
        
        purchase.refundRequested = true;
        
        emit RefundRequested(_courseId, msg.sender);
    }
    
    /**
     * @dev Process a refund request
     * @param _courseId Course ID
     * @param _buyer Address of the buyer
     */
    function processRefund(uint256 _courseId, address _buyer) 
        external
        courseExists(_courseId)
        whenNotPaused
        nonReentrant
    {
        Purchase storage purchase = userPurchases[_buyer][_courseId];
        require(purchase.purchaseDate > 0, "Course not purchased");
        require(purchase.refundRequested, "No refund requested");
        require(!purchase.refunded, "Already refunded");
        require(!purchase.completed, "Cannot refund completed course");
        
        Course storage course = courses[_courseId];
        
        // Calculate platform fee
        uint256 platformFee = (course.price * platformFeePercent) / 100;
        uint256 creatorAmount = course.price - platformFee;
        
        // Deduct amount from creator balance
        require(creatorBalance[course.creator] >= creatorAmount, "Insufficient creator balance");
        creatorBalance[course.creator] -= creatorAmount;
        
        // Mark as refunded
        purchase.refunded = true;
        
        // Update course statistics
        course.totalSales--;
        course.totalRevenue -= course.price;
        course.enrolledUsers--;
        
        // Transfer refund amount
        payable(_buyer).transfer(course.price);
        
        emit RefundProcessed(_courseId, _buyer, course.price);
    }
    
    /**
     * @dev Creator withdraws their balance
     */
    function creatorWithdraw() 
        external
        whenNotPaused
        nonReentrant
    {
        uint256 amount = creatorBalance[msg.sender];
        require(amount > 0, "No balance to withdraw");
        
        creatorBalance[msg.sender] = 0;
        
        payable(msg.sender).transfer(amount);
        
        emit CreatorWithdrawal(msg.sender, amount);
    }
    
    /**
     * @dev Owner withdraws platform fees
     */
    function ownerWithdraw() 
        external 
        onlyOwner
        whenNotPaused
        nonReentrant
    {
        uint256 platformBalance = address(this).balance;
        for (uint256 i = 1; i <= courseCounter; i++) {
            platformBalance -= creatorBalance[courses[i].creator];
        }
        
        require(platformBalance > 0, "No balance to withdraw");
        
        payable(owner()).transfer(platformBalance);
    }
    
    /**
     * @dev Change the platform fee percentage
     * @param _newFeePercent New platform fee percentage
     */
    function changePlatformFee(uint256 _newFeePercent) 
        external 
        onlyOwner
    {
        require(_newFeePercent <= 30, "Fee cannot exceed 30%");
        platformFeePercent = _newFeePercent;
    }

    /**
     * @dev Set the Mentora token address
     * @param _mentoraToken Address of the MentoraToken contract
     */
    function setMentoraToken(address _mentoraToken) 
        external 
        onlyOwner
    {
        require(_mentoraToken != address(0), "Invalid token address");
        mentoraToken = MentoraToken(_mentoraToken);
    }
    
    /**
     * @dev Get course information (public fields)
     * @param _courseId ID of the course
     */
    function getCourseInfo(uint256 _courseId)
        external
        view
        courseExists(_courseId)
        returns (
            uint256 id,
            string memory title,
            string memory description,
            string memory category,
            string memory thumbnailIpfsHash,
            uint256 difficulty,
            uint256 duration
        )
    {
        Course storage course = courses[_courseId];
        return (
            course.id,
            course.title, 
            course.description,
            course.category,
            course.thumbnailIpfsHash,
            course.difficulty,
            course.duration
        );
    }

    function getCourseStats(uint256 _courseId)
        external
        view 
        courseExists(_courseId)
        returns (
            address creator,
            bool isActive,
            uint256 price,
            uint256 totalSales,
            uint256 moduleCount,
            uint256 enrolledUsers
        )
    {
        Course storage course = courses[_courseId];
        return (
            course.creator,
            course.isActive,
            course.price,
            course.totalSales,
            course.moduleCount,
            course.enrolledUsers
        );
    }
    
    /**
     * @dev Get course content IPFS hash
     * @param _courseId ID of the course
     * @return IPFS hash of the course content JSON
     */
    function getCourseContent(uint256 _courseId) 
        external 
        view 
        courseExists(_courseId)
        hasPurchasedCourse(_courseId)
        returns (string memory) 
    {
        return courseContents[_courseId].contentIpfsHash;
    }
    
    /**
     * @dev Get course preview content IPFS hash (available for all users)
     * @param _courseId ID of the course
     * @return IPFS hash of the course content JSON
     */
    function getCoursePreview(uint256 _courseId) 
        external 
        view 
        courseExists(_courseId) 
        returns (string memory) 
    {
        return courseContents[_courseId].contentIpfsHash;
    }
    
    /**
     * @dev Get number of courses owned by an address
     * @param _user Address to check
     * @return Number of courses
     */
    function getUserCourseCount(address _user) external view returns (uint256) {
        return userCourseIds[_user].length;
    }
    
    /**
     * @dev Get number of courses created by an address
     * @param _creator Address to check
     * @return Number of courses
     */
    function getCreatorCourseCount(address _creator) external view returns (uint256) {
        return creatorCourseIds[_creator].length;
    }
    
    /**
     * @dev Check if user has purchased a course
     * @param _user User address
     * @param _courseId Course ID
     * @return Boolean indicating ownership
     */
    function hasUserPurchasedCourse(address _user, uint256 _courseId) external view returns (bool) {
        return userPurchases[_user][_courseId].purchaseDate > 0 && !userPurchases[_user][_courseId].refunded;
    }

    /**
     * @dev Check if user has completed a course
     * @param _user User address
     * @param _courseId Course ID
     * @return Boolean indicating completion status
     */
    function hasUserCompletedCourse(address _user, uint256 _courseId) external view returns (bool) {
        return userPurchases[_user][_courseId].completed;
    }

    /**
     * @dev Get completion date of a course
     * @param _user User address
     * @param _courseId Course ID
     * @return Timestamp of completion or 0 if not completed
     */
    function getUserCourseCompletionDate(address _user, uint256 _courseId) external view returns (uint256) {
        return userPurchases[_user][_courseId].completedDate;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
