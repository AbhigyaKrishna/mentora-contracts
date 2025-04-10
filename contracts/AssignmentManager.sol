// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MentoraToken} from "./MentoraToken.sol";

contract AssignmentManager is Ownable, Pausable, AccessControl, ReentrancyGuard {
    struct Assignment {
        string title;
        string description;
        string question;
        string[] evaluationCriteria;
        string metaPromptIpfsHash;
        uint256 createdAt;
        address creator;
        bool isActive;
    }

    struct Submission {
        uint256 assignmentId;
        address student;
        string solutionIpfsHash;
        uint256 submittedAt;
        bool isGraded;
        uint256 grade;
        string feedback;
        bool isRewarded;
    }

    bytes32 public constant TEACHER_ROLE = keccak256("TEACHER_ROLE");
    bytes32 public constant STUDENT_ROLE = keccak256("STUDENT_ROLE");
    bytes32 public constant GRADER_ROLE = keccak256("GRADER_ROLE");

    // Passing grade threshold (out of 100)
    uint256 public passingGradeThreshold = 70;

    // MentoraToken instance
    MentoraToken public mentoraToken;

    // Mapping to store assignments by their ID
    mapping(uint256 => Assignment) public assignments;
    
    // Counter for assignment IDs
    uint256 public assignmentCounter;

    // Mapping to store submissions (assignmentId => student => submission)
    mapping(uint256 => mapping(address => Submission)) public submissions;
    
    // Mapping to track all students who submitted a specific assignment
    mapping(uint256 => address[]) public assignmentSubmitters;
    
    // Mapping to track all assignments submitted by a student
    mapping(address => uint256[]) public studentSubmissions;

    // Events
    event AssignmentCreated(uint256 indexed assignmentId, address indexed creator);
    event AssignmentUpdated(uint256 indexed assignmentId);
    event AssignmentDeactivated(uint256 indexed assignmentId);
    event AssignmentSubmitted(uint256 indexed assignmentId, address indexed student, string solutionIpfsHash);
    event AssignmentGraded(uint256 indexed assignmentId, address indexed student, uint256 grade);
    event AssignmentRewarded(uint256 indexed assignmentId, address indexed student, uint256 rewardAmount);

    constructor(address _mentoraToken) Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TEACHER_ROLE, msg.sender);
        _grantRole(GRADER_ROLE, msg.sender);
        
        mentoraToken = MentoraToken(_mentoraToken);
    }

    // Modifiers
    modifier onlyCreator(uint256 _assignmentId) {
        require(assignments[_assignmentId].creator == msg.sender, "Only creator can modify");
        _;
    }

    modifier assignmentExists(uint256 _assignmentId) {
        require(_assignmentId < assignmentCounter, "Assignment does not exist");
        _;
    }

    modifier notSubmitted(uint256 _assignmentId) {
        require(submissions[_assignmentId][msg.sender].submittedAt == 0, "Already submitted");
        _;
    }

    modifier hasSubmitted(uint256 _assignmentId, address _student) {
        require(submissions[_assignmentId][_student].submittedAt > 0, "No submission found");
        _;
    }

    modifier notGraded(uint256 _assignmentId, address _student) {
        require(!submissions[_assignmentId][_student].isGraded, "Already graded");
        _;
    }

    modifier isGraded(uint256 _assignmentId, address _student) {
        require(submissions[_assignmentId][_student].isGraded, "Not graded yet");
        _;
    }

    modifier notRewarded(uint256 _assignmentId, address _student) {
        require(!submissions[_assignmentId][_student].isRewarded, "Already rewarded");
        _;
    }

    // Functions
    function createAssignment(
        string calldata _title,
        string calldata _description,
        string calldata _question,
        string[] calldata _evaluationCriteria,
        string calldata _metaPromptIpfsHash
    ) public onlyRole(TEACHER_ROLE) whenNotPaused nonReentrant returns (uint256) {
        uint256 assignmentId = assignmentCounter++;
        
        assignments[assignmentId] = Assignment({
            title: _title,
            description: _description,
            question: _question,
            evaluationCriteria: _evaluationCriteria,
            metaPromptIpfsHash: _metaPromptIpfsHash,
            createdAt: block.timestamp,
            creator: msg.sender,
            isActive: true
        });

        emit AssignmentCreated(assignmentId, msg.sender);
        return assignmentId;
    }

    function updateAssignment(
        uint256 _assignmentId,
        string calldata _title,
        string calldata _description,
        string calldata _question,
        string[] calldata _evaluationCriteria,
        string calldata _metaPromptIpfsHash
    ) public assignmentExists(_assignmentId) onlyCreator(_assignmentId) whenNotPaused nonReentrant {
        Assignment storage assignment = assignments[_assignmentId];
        require(assignment.isActive, "Assignment is not active");

        assignment.title = _title;
        assignment.description = _description;
        assignment.question = _question;
        assignment.evaluationCriteria = _evaluationCriteria;
        assignment.metaPromptIpfsHash = _metaPromptIpfsHash;

        emit AssignmentUpdated(_assignmentId);
    }

    function deactivateAssignment(uint256 _assignmentId) 
        public 
        assignmentExists(_assignmentId) 
        onlyCreator(_assignmentId)
        whenNotPaused
        nonReentrant
    {
        assignments[_assignmentId].isActive = false;
        emit AssignmentDeactivated(_assignmentId);
    }

    function submitAssignment(
        uint256 _assignmentId,
        string calldata _solutionIpfsHash
    )
        public
        assignmentExists(_assignmentId)
        onlyRole(STUDENT_ROLE)
        notSubmitted(_assignmentId)
        whenNotPaused
        nonReentrant
    {
        require(assignments[_assignmentId].isActive, "Assignment is not active");
        require(bytes(_solutionIpfsHash).length > 0, "Solution hash cannot be empty");

        submissions[_assignmentId][msg.sender] = Submission({
            assignmentId: _assignmentId,
            student: msg.sender,
            solutionIpfsHash: _solutionIpfsHash,
            submittedAt: block.timestamp,
            isGraded: false,
            grade: 0,
            feedback: "",
            isRewarded: false
        });

        assignmentSubmitters[_assignmentId].push(msg.sender);
        studentSubmissions[msg.sender].push(_assignmentId);

        emit AssignmentSubmitted(_assignmentId, msg.sender, _solutionIpfsHash);
    }

    function gradeAssignment(
        uint256 _assignmentId,
        address _student,
        uint256 _grade,
        string calldata _feedback
    )
        public
        assignmentExists(_assignmentId)
        onlyRole(GRADER_ROLE)
        hasSubmitted(_assignmentId, _student)
        notGraded(_assignmentId, _student)
        whenNotPaused
        nonReentrant
    {
        require(_grade <= 100, "Grade cannot exceed 100");
        
        Submission storage submission = submissions[_assignmentId][_student];
        submission.isGraded = true;
        submission.grade = _grade;
        submission.feedback = _feedback;

        emit AssignmentGraded(_assignmentId, _student, _grade);

        // If passing grade and MentoraToken is set, process rewards
        if (_grade >= passingGradeThreshold && address(mentoraToken) != address(0)) {
            _rewardAssignmentCompletion(_assignmentId, _student);
        }
    }

    function _rewardAssignmentCompletion(uint256 _assignmentId, address _student) 
        internal
        notRewarded(_assignmentId, _student)
    {
        Submission storage submission = submissions[_assignmentId][_student];
        submission.isRewarded = true;

        // Call MentoraToken to reward the student
        mentoraToken.rewardAssignmentCompletion(_student);
        
        uint256 rewardAmount = mentoraToken.assignmentCompletionReward();
        emit AssignmentRewarded(_assignmentId, _student, rewardAmount);
    }

    function setPassingGradeThreshold(uint256 _threshold) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
    {
        require(_threshold <= 100, "Threshold cannot exceed 100");
        passingGradeThreshold = _threshold;
    }

    function setMentoraToken(address _mentoraToken)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
    {
        require(_mentoraToken != address(0), "Invalid token address");
        mentoraToken = MentoraToken(_mentoraToken);
    }

    function getAssignment(uint256 _assignmentId) 
        public 
        view 
        assignmentExists(_assignmentId) 
        returns (
            string memory title,
            string memory description,
            string memory question,
            string[] memory evaluationCriteria,
            string memory metaPromptIpfsHash,
            uint256 createdAt,
            address creator,
            bool isActive
        ) 
    {
        Assignment storage assignment = assignments[_assignmentId];
        return (
            assignment.title,
            assignment.description,
            assignment.question,
            assignment.evaluationCriteria,
            assignment.metaPromptIpfsHash,
            assignment.createdAt,
            assignment.creator,
            assignment.isActive
        );
    }

    function getSubmission(uint256 _assignmentId, address _student)
        public
        view
        assignmentExists(_assignmentId)
        hasSubmitted(_assignmentId, _student)
        returns (
            string memory solutionIpfsHash,
            uint256 submittedAt,
            bool isGraded,
            uint256 grade,
            string memory feedback,
            bool isRewarded
        )
    {
        Submission storage submission = submissions[_assignmentId][_student];
        return (
            submission.solutionIpfsHash,
            submission.submittedAt,
            submission.isGraded,
            submission.grade,
            submission.feedback,
            submission.isRewarded
        );
    }

    function getAssignmentSubmissionCount(uint256 _assignmentId)
        public
        view
        assignmentExists(_assignmentId)
        returns (uint256)
    {
        return assignmentSubmitters[_assignmentId].length;
    }

    function getStudentSubmissionCount(address _student)
        public
        view
        returns (uint256)
    {
        return studentSubmissions[_student].length;
    }

    function getAssignmentQuestion(uint256 _assignmentId) 
        public 
        view 
        assignmentExists(_assignmentId) 
        returns (string memory) 
    {
        return assignments[_assignmentId].question;
    }

    function getAssignmentEvaluationCriteria(uint256 _assignmentId) 
        public 
        view 
        assignmentExists(_assignmentId) 
        returns (string[] memory) 
    {
        return assignments[_assignmentId].evaluationCriteria;
    }

    function getAssignmentMetaPromptIpfsHash(uint256 _assignmentId) 
        public 
        view 
        assignmentExists(_assignmentId) 
        returns (string memory) 
    {
        return assignments[_assignmentId].metaPromptIpfsHash;
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
} 