// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract AssignmentManager {
    struct Assignment {
        string title;
        string description;
        string question;
        string evaluationCriteria;
        string metaPrompt;
        uint256 createdAt;
        address creator;
        bool isActive;
    }

    // Mapping to store assignments by their ID
    mapping(uint256 => Assignment) public assignments;
    
    // Counter for assignment IDs
    uint256 private assignmentCounter;

    // Events
    event AssignmentCreated(uint256 indexed assignmentId, address indexed creator);
    event AssignmentUpdated(uint256 indexed assignmentId);
    event AssignmentDeactivated(uint256 indexed assignmentId);

    // Modifiers
    modifier onlyCreator(uint256 _assignmentId) {
        require(assignments[_assignmentId].creator == msg.sender, "Only creator can modify");
        _;
    }

    modifier assignmentExists(uint256 _assignmentId) {
        require(_assignmentId < assignmentCounter, "Assignment does not exist");
        _;
    }

    // Functions
    function createAssignment(
        string memory _title,
        string memory _description,
        string memory _question,
        string memory _evaluationCriteria,
        string memory _metaPrompt
    ) public returns (uint256) {
        uint256 assignmentId = assignmentCounter++;
        
        assignments[assignmentId] = Assignment({
            title: _title,
            description: _description,
            question: _question,
            evaluationCriteria: _evaluationCriteria,
            metaPrompt: _metaPrompt,
            createdAt: block.timestamp,
            creator: msg.sender,
            isActive: true
        });

        emit AssignmentCreated(assignmentId, msg.sender);
        return assignmentId;
    }

    function updateAssignment(
        uint256 _assignmentId,
        string memory _title,
        string memory _description,
        string memory _question,
        string memory _evaluationCriteria,
        string memory _metaPrompt
    ) public assignmentExists(_assignmentId) onlyCreator(_assignmentId) {
        Assignment storage assignment = assignments[_assignmentId];
        require(assignment.isActive, "Assignment is not active");

        assignment.title = _title;
        assignment.description = _description;
        assignment.question = _question;
        assignment.evaluationCriteria = _evaluationCriteria;
        assignment.metaPrompt = _metaPrompt;

        emit AssignmentUpdated(_assignmentId);
    }

    function deactivateAssignment(uint256 _assignmentId) 
        public 
        assignmentExists(_assignmentId) 
        onlyCreator(_assignmentId) 
    {
        assignments[_assignmentId].isActive = false;
        emit AssignmentDeactivated(_assignmentId);
    }

    function getAssignment(uint256 _assignmentId) 
        public 
        view 
        assignmentExists(_assignmentId) 
        returns (
            string memory title,
            string memory description,
            string memory question,
            string memory evaluationCriteria,
            string memory metaPrompt,
            uint256 createdAt,
            address creator,
            bool isActive
        ) 
    {
        Assignment memory assignment = assignments[_assignmentId];
        return (
            assignment.title,
            assignment.description,
            assignment.question,
            assignment.evaluationCriteria,
            assignment.metaPrompt,
            assignment.createdAt,
            assignment.creator,
            assignment.isActive
        );
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
        returns (string memory) 
    {
        return assignments[_assignmentId].evaluationCriteria;
    }

    function getAssignmentMetaPrompt(uint256 _assignmentId) 
        public 
        view 
        assignmentExists(_assignmentId) 
        returns (string memory) 
    {
        return assignments[_assignmentId].metaPrompt;
    }
} 