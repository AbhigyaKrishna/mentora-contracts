// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CourseMarketplace
 * @dev Smart contract for managing and selling educational courses on blockchain with IPFS content storage
 */
contract Mentora {
    address public owner;
    uint256 public courseCounter;
    uint256 public platformFeePercent;
    
    struct CourseContent {
        string introVideoIpfsHash;
        string[] moduleIpfsHashes;
        string[] moduleTitles;
        mapping(uint256 => string) materialIpfsHashes; // Additional materials per module
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
    }
    
    // Storage
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
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
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
    
    constructor(uint256 _platformFeePercent) {
        owner = msg.sender;
        courseCounter = 0;
        platformFeePercent = _platformFeePercent;
    }
    
    /**
     * @dev Create a new course
     * @param _title Course title
     * @param _description Course description
     * @param _thumbnailIpfsHash IPFS hash of the course thumbnail
     * @param _introVideoIpfsHash IPFS hash of the intro/preview video
     * @param _price Course price in wei
     */
    function createCourse(
        string memory _title,
        string memory _description,
        string memory _category,
        string memory _thumbnailIpfsHash,
        string memory _introVideoIpfsHash,
        uint256 _difficulty,
        uint256 _duration,
        uint256 _price
    ) external {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_thumbnailIpfsHash).length > 0, "Thumbnail IPFS hash cannot be empty");
        require(bytes(_introVideoIpfsHash).length > 0, "Intro video IPFS hash cannot be empty");
        require(_price > 0, "Price must be greater than zero");
        
        courseCounter++;
        
        // Create new course
        Course storage newCourse = courses[courseCounter];
        newCourse.id = courseCounter;
        newCourse.title = _title;
        newCourse.description = _description;
        newCourse.category = _category;
        newCourse.thumbnailIpfsHash = _thumbnailIpfsHash;
        newCourse.difficulty = _difficulty; // Default difficulty
        newCourse.creator = msg.sender;
        newCourse.price = _price;
        newCourse.isActive = true;
        newCourse.totalSales = 0;
        newCourse.totalRevenue = 0;
        newCourse.moduleCount = 0;
        newCourse.enrolledUsers = 0;
        newCourse.duration = _duration;
        
        // Initialize course content
        CourseContent storage newContent = courseContents[courseCounter];
        newContent.introVideoIpfsHash = _introVideoIpfsHash;
        newContent.materialCount = 0;
        
        creatorCourseIds[msg.sender].push(courseCounter);
        
        emit CourseCreated(courseCounter, _title, msg.sender, _price);
    }
    
    /**
     * @dev Add a module to an existing course
     * @param _courseId ID of the course
     * @param _moduleTitle Title of the module
     * @param _moduleIpfsHash IPFS hash of the module video
     */
    function addModule(
        uint256 _courseId,
        string memory _moduleTitle,
        string memory _moduleIpfsHash
    ) 
        external 
        courseExists(_courseId)
        onlyCourseCreator(_courseId)
    {
        require(bytes(_moduleTitle).length > 0, "Module title cannot be empty");
        require(bytes(_moduleIpfsHash).length > 0, "Module IPFS hash cannot be empty");
        
        Course storage course = courses[_courseId];
        CourseContent storage content = courseContents[_courseId];
        
        // Add module
        content.moduleIpfsHashes.push(_moduleIpfsHash);
        content.moduleTitles.push(_moduleTitle);
        
        // Update course module count
        course.moduleCount++;
        
        emit ModuleAdded(_courseId, course.moduleCount - 1, _moduleTitle);
        emit CourseContentUpdated(_courseId, course.moduleCount);
    }
    
    /**
     * @dev Add additional material to a module
     * @param _courseId ID of the course
     * @param _moduleIndex Index of the module
     * @param _materialIpfsHash IPFS hash of the material
     */
    function addMaterial(
        uint256 _courseId,
        uint256 _moduleIndex,
        string memory _materialIpfsHash
    )
        external
        courseExists(_courseId)
        onlyCourseCreator(_courseId)
    {
        require(_moduleIndex < courses[_courseId].moduleCount, "Module index out of bounds");
        require(bytes(_materialIpfsHash).length > 0, "Material IPFS hash cannot be empty");
        
        CourseContent storage content = courseContents[_courseId];
        content.materialIpfsHashes[content.materialCount] = _materialIpfsHash;
        content.materialCount++;
        
        emit MaterialAdded(_courseId, _moduleIndex, content.materialCount - 1);
    }
    
    /**
     * @dev Update course details
     * @param _courseId ID of the course to update
     * @param _title New course title
     * @param _description New course description
     * @param _thumbnailIpfsHash New thumbnail IPFS hash
     * @param _introVideoIpfsHash New intro video IPFS hash
     * @param _price New course price in wei
     * @param _isActive Course active status
     */
    function updateCourse(
        uint256 _courseId, 
        string memory _title, 
        string memory _description,
        string memory _thumbnailIpfsHash,
        string memory _introVideoIpfsHash,
        uint256 _price, 
        bool _isActive
    ) 
        external 
        courseExists(_courseId) 
        onlyCourseCreator(_courseId) 
    {
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_thumbnailIpfsHash).length > 0, "Thumbnail IPFS hash cannot be empty");
        require(bytes(_introVideoIpfsHash).length > 0, "Intro video IPFS hash cannot be empty");
        require(_price > 0, "Price must be greater than zero");
        
        Course storage course = courses[_courseId];
        course.title = _title;
        course.description = _description;
        course.thumbnailIpfsHash = _thumbnailIpfsHash;
        course.price = _price;
        course.isActive = _isActive;
        
        CourseContent storage content = courseContents[_courseId];
        content.introVideoIpfsHash = _introVideoIpfsHash;
        
        emit CourseUpdated(_courseId, _title, _price, _isActive);
    }
    
    /**
     * @dev Update a module's content
     * @param _courseId ID of the course
     * @param _moduleIndex Index of the module to update
     * @param _moduleTitle New module title
     * @param _moduleIpfsHash New module IPFS hash
     */
    function updateModule(
        uint256 _courseId,
        uint256 _moduleIndex,
        string memory _moduleTitle,
        string memory _moduleIpfsHash
    )
        external
        courseExists(_courseId)
        onlyCourseCreator(_courseId)
    {
        require(_moduleIndex < courses[_courseId].moduleCount, "Module index out of bounds");
        require(bytes(_moduleTitle).length > 0, "Module title cannot be empty");
        require(bytes(_moduleIpfsHash).length > 0, "Module IPFS hash cannot be empty");
        
        CourseContent storage content = courseContents[_courseId];
        content.moduleTitles[_moduleIndex] = _moduleTitle;
        content.moduleIpfsHashes[_moduleIndex] = _moduleIpfsHash;
        
        emit ModuleAdded(_courseId, _moduleIndex, _moduleTitle);
    }
    
    /**
     * @dev Delist a course
     * @param _courseId ID of the course to delist
     */
    function delistCourse(uint256 _courseId) 
        external 
        courseExists(_courseId) 
        onlyCourseCreator(_courseId) 
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
            refunded: false
        });
        
        userCourseIds[msg.sender].push(_courseId);
        
        // Refund excess payment
        if (msg.value > course.price) {
            payable(msg.sender).transfer(msg.value - course.price);
        }
        
        emit CoursePurchased(_courseId, msg.sender, course.price);
    }
    
    /**
     * @dev Request a refund for a purchased course
     * @param _courseId ID of the course for refund
     */
    function requestRefund(uint256 _courseId) external courseExists(_courseId) {
        Purchase storage purchase = userPurchases[msg.sender][_courseId];
        require(purchase.purchaseDate > 0, "Course not purchased");
        require(!purchase.refundRequested, "Refund already requested");
        require(!purchase.refunded, "Already refunded");
        
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
        onlyOwner 
        courseExists(_courseId) 
    {
        Purchase storage purchase = userPurchases[_buyer][_courseId];
        require(purchase.purchaseDate > 0, "Course not purchased");
        require(purchase.refundRequested, "No refund requested");
        require(!purchase.refunded, "Already refunded");
        
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
    function creatorWithdraw() external {
        uint256 amount = creatorBalance[msg.sender];
        require(amount > 0, "No balance to withdraw");
        
        creatorBalance[msg.sender] = 0;
        
        payable(msg.sender).transfer(amount);
        
        emit CreatorWithdrawal(msg.sender, amount);
    }
    
    /**
     * @dev Owner withdraws platform fees
     */
    function ownerWithdraw() external onlyOwner {
        uint256 platformBalance = address(this).balance;
        for (uint256 i = 1; i <= courseCounter; i++) {
            platformBalance -= creatorBalance[courses[i].creator];
        }
        
        require(platformBalance > 0, "No balance to withdraw");
        
        payable(owner).transfer(platformBalance);
    }
    
    /**
     * @dev Change the platform fee percentage
     * @param _newFeePercent New platform fee percentage
     */
    function changePlatformFee(uint256 _newFeePercent) external onlyOwner {
        require(_newFeePercent <= 30, "Fee cannot exceed 30%");
        platformFeePercent = _newFeePercent;
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
            address creator,
            uint256 price,
            bool isActive,
            uint256 totalSales,
            uint256 moduleCount,
            uint256 enrolledUsers,
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
            course.creator,
            course.price,
            course.isActive,
            course.totalSales,
            course.moduleCount,
            course.enrolledUsers,
            course.duration
        );
    }
    
    /**
     * @dev Get intro video IPFS hash (available for all users)
     * @param _courseId ID of the course
     * @return IPFS hash of the intro video
     */
    function getCourseIntroVideo(uint256 _courseId) 
        external 
        view 
        courseExists(_courseId) 
        returns (string memory) 
    {
        return courseContents[_courseId].introVideoIpfsHash;
    }
    
    /**
     * @dev Get module titles (available for all users)
     * @param _courseId ID of the course
     * @return Array of module titles
     */
    function getModuleTitles(uint256 _courseId) 
        external 
        view 
        courseExists(_courseId) 
        returns (string[] memory) 
    {
        return courseContents[_courseId].moduleTitles;
    }
    
    /**
     * @dev Get module video IPFS hash (available only for course owners)
     * @param _courseId ID of the course
     * @param _moduleIndex Index of the module
     * @return IPFS hash of the module video
     */
    function getModuleVideo(uint256 _courseId, uint256 _moduleIndex) 
        external 
        view 
        courseExists(_courseId)
        hasPurchasedCourse(_courseId)
        returns (string memory) 
    {
        require(_moduleIndex < courses[_courseId].moduleCount, "Module index out of bounds");
        return courseContents[_courseId].moduleIpfsHashes[_moduleIndex];
    }
    
    /**
     * @dev Get material IPFS hash (available only for course owners)
     * @param _courseId ID of the course
     * @param _materialIndex Index of the material
     * @return IPFS hash of the material
     */
    function getMaterial(uint256 _courseId, uint256 _materialIndex) 
        external 
        view 
        courseExists(_courseId)
        hasPurchasedCourse(_courseId)
        returns (string memory) 
    {
        require(_materialIndex < courseContents[_courseId].materialCount, "Material index out of bounds");
        return courseContents[_courseId].materialIpfsHashes[_materialIndex];
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
}
