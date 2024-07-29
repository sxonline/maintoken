// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract SUNXToken is ERC20, Ownable, Pausable {
    uint256 public constant MAX_SUPPLY = 500 * 60 * 24 * 365 * (2050 - 2023 + 1) * 10**6; // Tokens until the end of 2050
    uint256 public constant COINS_PER_MINUTE = 500 * 10**6; // Mimics SUNX Coin Block Reward
    uint256 public constant MAX_TRANSFER_LIMIT = 1 * 10**7 * 10**6; // Limit of 10,000,000 tokens per transfer
    uint256 public constant INITIAL_OWNER_SUPPLY = 2.1 * 10**9 * 10**6; // 2.1 billion tokens
    uint256 public immutable creationTime;

    address[] public signatories;
    uint256 public approvalThreshold;
    mapping(bytes32 => uint256) public approvals;
    mapping(bytes32 => uint256) public pauseApprovals;
    mapping(bytes32 => uint256) public unpauseApprovals;
    mapping(address => uint256) public nonces;
    mapping(bytes32 => mapping(address => bool)) public approvedBy;
    mapping(bytes32 => mapping(address => bool)) public pauseApprovedBy;
    mapping(bytes32 => mapping(address => bool)) public unpauseApprovedBy;

    event TokensTransferred(address indexed recipient, uint256 amount);
    event TokensBurned(uint256 amount);
    event TransactionApproved(bytes32 indexed approveHash, address indexed approver);
    event Transactioncall(bytes32 indexed approveHash);
    event ApproveHashCheck(bytes32 indexed approveHash);
    event ApproveCount(uint256 amount);


    event PauseApproved(bytes32 indexed approveHash, address indexed approver);
    event UnpauseApproved(bytes32 indexed approveHash, address indexed approver);

    constructor(address initialOwner, address[] memory _signatories, uint256 _threshold) ERC20("SUNX Token", "SUNX") Ownable(initialOwner) {
        require(_signatories.length >= _threshold, "Not enough signatories");

        creationTime = block.timestamp;
        _mint(address(this), MAX_SUPPLY);
        _transfer(address(this), initialOwner, INITIAL_OWNER_SUPPLY);

        signatories = _signatories;
        approvalThreshold = _threshold;
 
    }

    modifier onlySignatory() {
        require(isSignatory(msg.sender), "Not a signatory");
        _;
    }

    function isSignatory(address account) public view returns (bool) {
        for (uint256 i = 0; i < signatories.length; i++) {
            if (signatories[i] == account) {
                return true;
            }
        }
        return false;
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function proposeTransaction(bytes32 approveHash) external onlySignatory {
        require(approvals[approveHash] == 0, "Transaction already proposed");
        approvals[approveHash] = 1; // Initial approval by proposer
        approvedBy[approveHash][msg.sender] = true;
        emit TransactionApproved(approveHash, msg.sender);
    }

    function approveTransaction(bytes32 approveHash) external onlySignatory {
        require(approvals[approveHash] > 0, "Transaction not proposed yet");
        require(!approvedBy[approveHash][msg.sender], "Already approved by this signatory");
        approvals[approveHash]++;
        approvedBy[approveHash][msg.sender] = true;
        emit TransactionApproved(approveHash, msg.sender);
    }

    function hasApproval(bytes32 approveHash) public view returns (bool) {
        return approvals[approveHash] >= approvalThreshold;
    }

    function approvePause(bytes32 approveHash) external onlySignatory {
        require(!pauseApprovedBy[approveHash][msg.sender], "Already approved pause by this signatory");
        pauseApprovals[approveHash]++;
        pauseApprovedBy[approveHash][msg.sender] = true;
        emit PauseApproved(approveHash, msg.sender);
    }

    function approveUnpause(bytes32 approveHash) external onlySignatory {
        require(!unpauseApprovedBy[approveHash][msg.sender], "Already approved unpause by this signatory");
        unpauseApprovals[approveHash]++;
        unpauseApprovedBy[approveHash][msg.sender] = true;
        emit UnpauseApproved(approveHash, msg.sender);
    }

    function hasPauseApproval(bytes32 approveHash) public view returns (bool) {
        return pauseApprovals[approveHash] >= approvalThreshold;
    }

    function hasUnpauseApproval(bytes32 approveHash) public view returns (bool) {
        return unpauseApprovals[approveHash] >= approvalThreshold;
    }

    function pause(bytes32 approveHash) external onlySignatory {
        require(hasPauseApproval(approveHash), "Not enough approvals");
        pauseApprovals[approveHash] = 0;
        _pause();
    }

    function unpause(bytes32 approveHash) external onlySignatory {                                                                    
                                                                   
        require(hasUnpauseApproval(approveHash), "Not enough approvals");
        unpauseApprovals[approveHash] = 0;
        _unpause();
    }

  

  function approveCheck(address recipient, uint256 amount, address secret) external onlySignatory whenNotPaused {

        bytes32 approveHash = keccak256(abi.encodePacked("transfer", recipient, amount, secret));
        emit ApproveHashCheck(approveHash);
        emit ApproveCount(approvals[approveHash]);


  }

function transferBasedOnMining(address recipient, uint256 amount, address secret) external onlySignatory whenNotPaused {
/**
* @dev Function to transfer tokens based on mining conditions. 
* The function requires enough approval, checks if there's sufficient balance in contract and limit of maximum transfer amount.
* Emits an event `TokensTransferred` when the transaction is successful.
* Only signatories can call this function and it cannot be called while contract is paused.
* @param recipient The address to receive the tokens.
* @param amount The amount of tokens to transfer.
* @param secret A secret key for the transaction approval.
*/
        bytes32 approveHash = keccak256(abi.encodePacked("transfer", recipient, amount, secret));
        require(hasApproval(approveHash), "Not enough approvals");
        uint256 allowedAmount = allowableTransferAmount();
        require(balanceOf(address(this)) >= amount, "Not enough tokens in the contract");
        require(totalSupply() - balanceOf(address(this)) + amount - INITIAL_OWNER_SUPPLY <= allowedAmount, "Transfer amount exceeds allowable limit");
        require(amount <= MAX_TRANSFER_LIMIT, "Transfer amount exceeds maximum transfer limit");
      delete approvals[approveHash];
          for (uint256 i = 0; i < signatories.length; i++) {
        delete approvedBy[approveHash][signatories[i]];
    }
        _transfer(address(this), recipient, amount);
        emit TokensTransferred(recipient, amount);

 
    }

    function burnBasedOnMining(uint256 amount, bytes32 secret) external onlySignatory whenNotPaused {
        bytes32 approveHash = keccak256(abi.encodePacked("burn", amount, secret));
        require(hasApproval(approveHash), "Not enough approvals");
        require(balanceOf(address(this)) >= amount, "Not enough tokens in the contract");
        _burn(address(this), amount);
        emit TokensBurned(amount);
        delete approvals[approveHash];
          for (uint256 i = 0; i < signatories.length; i++) {
        delete approvedBy[approveHash][signatories[i]];
    }

    }

    function allowableTransferAmount() public view returns (uint256) {
        unchecked {
            uint256 minutesSinceCreation = (block.timestamp - creationTime) / 60;
            return minutesSinceCreation * COINS_PER_MINUTE;
        }
    }

 


}
