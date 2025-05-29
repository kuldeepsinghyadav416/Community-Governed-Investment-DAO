// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Project {
    // State variables
    address public owner;
    uint256 public totalFunds;
    uint256 public proposalCounter;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MIN_INVESTMENT = 0.1 ether;
    uint256 public constant PROPOSAL_THRESHOLD = 1 ether;
    
    // Structs
    struct Member {
        uint256 investment;
        uint256 votingPower;
        bool isActive;
        uint256 joinedAt;
    }
    
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 requestedAmount;
        address payable recipient;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        bool passed;
        mapping(address => bool) hasVoted;
    }
    
    // Mappings
    mapping(address => Member) public members;
    mapping(uint256 => Proposal) public proposals;
    address[] public membersList;
    
    // Events
    event MemberJoined(address indexed member, uint256 investment);
    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, uint256 requestedAmount);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support, uint256 votingPower);
    event ProposalExecuted(uint256 indexed proposalId, bool passed, uint256 amount);
    event FundsWithdrawn(address indexed member, uint256 amount);
    
    // Modifiers
    modifier onlyMember() {
        require(members[msg.sender].isActive, "Not an active member");
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    modifier validProposal(uint256 _proposalId) {
        require(_proposalId > 0 && _proposalId <= proposalCounter, "Invalid proposal ID");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        proposalCounter = 0;
    }
    
    // Core Function 1: Join DAO as a member with investment
    function joinDAO() external payable {
        require(msg.value >= MIN_INVESTMENT, "Minimum investment required");
        require(!members[msg.sender].isActive, "Already a member");
        
        members[msg.sender] = Member({
            investment: msg.value,
            votingPower: msg.value / 1 ether, // 1 voting power per 1 ETH
            isActive: true,
            joinedAt: block.timestamp
        });
        
        membersList.push(msg.sender);
        totalFunds += msg.value;
        
        emit MemberJoined(msg.sender, msg.value);
    }
    
    // Core Function 2: Create investment proposal
    function createProposal(
        string memory _description,
        uint256 _requestedAmount,
        address payable _recipient
    ) external onlyMember returns (uint256) {
        require(_requestedAmount > 0, "Amount must be greater than 0");
        require(_requestedAmount <= totalFunds, "Insufficient DAO funds");
        require(members[msg.sender].investment >= PROPOSAL_THRESHOLD, "Insufficient stake to propose");
        require(_recipient != address(0), "Invalid recipient address");
        
        proposalCounter++;
        
        Proposal storage newProposal = proposals[proposalCounter];
        newProposal.id = proposalCounter;
        newProposal.proposer = msg.sender;
        newProposal.description = _description;
        newProposal.requestedAmount = _requestedAmount;
        newProposal.recipient = _recipient;
        newProposal.deadline = block.timestamp + VOTING_PERIOD;
        newProposal.executed = false;
        newProposal.passed = false;
        
        emit ProposalCreated(proposalCounter, msg.sender, _requestedAmount);
        return proposalCounter;
    }
    
    // Core Function 3: Vote on proposals and execute if passed
    function voteAndExecute(uint256 _proposalId, bool _support) 
        external 
        onlyMember 
        validProposal(_proposalId) 
    {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp <= proposal.deadline, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(!proposal.executed, "Proposal already executed");
        
        uint256 votingPower = members[msg.sender].votingPower;
        proposal.hasVoted[msg.sender] = true;
        
        if (_support) {
            proposal.votesFor += votingPower;
        } else {
            proposal.votesAgainst += votingPower;
        }
        
        emit VoteCast(_proposalId, msg.sender, _support, votingPower);
        
        // Auto-execute if voting period ended
        if (block.timestamp > proposal.deadline) {
            _executeProposal(_proposalId);
        }
    }
    
    // Internal function to execute proposal
    function _executeProposal(uint256 _proposalId) internal {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Already executed");
        
        proposal.executed = true;
        
        // Check if proposal passed (simple majority)
        if (proposal.votesFor > proposal.votesAgainst) {
            proposal.passed = true;
            
            // Transfer funds if DAO has sufficient balance
            if (address(this).balance >= proposal.requestedAmount) {
                totalFunds -= proposal.requestedAmount;
                proposal.recipient.transfer(proposal.requestedAmount);
            }
        }
        
        emit ProposalExecuted(_proposalId, proposal.passed, proposal.requestedAmount);
    }
    
    // Execute proposal manually (if voting period ended)
    function executeProposal(uint256 _proposalId) 
        external 
        validProposal(_proposalId) 
    {
        Proposal storage proposal = proposals[_proposalId];
        require(block.timestamp > proposal.deadline, "Voting still active");
        require(!proposal.executed, "Already executed");
        
        _executeProposal(_proposalId);
    }
    
    // Get proposal details
    function getProposal(uint256 _proposalId) 
        external 
        view 
        validProposal(_proposalId) 
        returns (
            uint256 id,
            address proposer,
            string memory description,
            uint256 requestedAmount,
            address recipient,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 deadline,
            bool executed,
            bool passed
        ) 
    {
        Proposal storage proposal = proposals[_proposalId];
        return (
            proposal.id,
            proposal.proposer,
            proposal.description,
            proposal.requestedAmount,
            proposal.recipient,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.deadline,
            proposal.executed,
            proposal.passed
        );
    }
    
    // Get member details
    function getMember(address _member) 
        external 
        view 
        returns (
            uint256 investment,
            uint256 votingPower,
            bool isActive,
            uint256 joinedAt
        ) 
    {
        Member memory member = members[_member];
        return (member.investment, member.votingPower, member.isActive, member.joinedAt);
    }
    
    // Get DAO statistics
    function getDAOStats() 
        external 
        view 
        returns (
            uint256 _totalFunds,
            uint256 _totalMembers,
            uint256 _totalProposals,
            uint256 _contractBalance
        ) 
    {
        return (totalFunds, membersList.length, proposalCounter, address(this).balance);
    }
    
    // Emergency withdrawal (only owner)
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    // Receive function to accept direct ETH transfers
    receive() external payable {
        totalFunds += msg.value;
    }
}
