// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./SkoreSBT.sol";

/**
 * @title SkoreOracle
 * @author Skoré Protocol
 * @notice Receives score data from off-chain API and forwards to SkoreSBT
 * @dev Trusted oracle pattern — v2 will use Chainlink Functions
 *      Kwala Workflow 1 listens to ScoreRequested on SkoreSBT
 *      then calls our Node.js API which calls submitScore() here
 */
contract SkoreOracle is Ownable {

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SkoreOracle__NotAuthorizedCaller();
    error SkoreOracle__ZeroAddress();
    error SkoreOracle__InvalidScore();
    error SkoreOracle__RequestNotFound();
    error SkoreOracle__AlreadyProcessed();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    SkoreSBT public immutable skoreSBT;

    /// @notice authorized callers — our Node.js API wallet
    mapping(address => bool) public authorizedCallers;

    /// @notice request tracking
    mapping(bytes32 => bool) public processedRequests;

    uint256 public totalScoresIssued;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ScoreSubmitted(
        address indexed wallet,
        uint256 score,
        bytes32 indexed requestId,
        uint256 timestamp
    );

    event CallerAuthorized(address indexed caller);
    event CallerRevoked(address indexed caller);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAuthorized() {
        if (!authorizedCallers[msg.sender]) {
            revert SkoreOracle__NotAuthorizedCaller();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _skoreSBT) Ownable(msg.sender) {
        if (_skoreSBT == address(0)) revert SkoreOracle__ZeroAddress();
        skoreSBT = SkoreSBT(_skoreSBT);
        // Authorize deployer as first caller
        authorizedCallers[msg.sender] = true;
        emit CallerAuthorized(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Submit a computed score for a wallet
     * @dev Called by our Node.js scoring API after computing score
     *      Forwards data to SkoreSBT to mint/update soulbound token
     * @param wallet The wallet being scored
     * @param score Computed score 300-850
     * @param totalTx Total lifetime transactions
     * @param ageMonths Wallet age in months
     * @param hasDefi Whether wallet has DeFi history
     * @param chainCount Number of chains active on
     * @param requestId Unique ID to prevent duplicate submissions
     */
    function submitScore(
        address wallet,
        uint256 score,
        uint256 totalTx,
        uint256 ageMonths,
        bool hasDefi,
        uint8 chainCount,
        bytes32 requestId
    ) external onlyAuthorized {
        if (wallet == address(0)) revert SkoreOracle__ZeroAddress();
        if (score < 300 || score > 850) revert SkoreOracle__InvalidScore();
        if (processedRequests[requestId]) revert SkoreOracle__AlreadyProcessed();

        processedRequests[requestId] = true;
        totalScoresIssued++;

        skoreSBT.issueScore(
            wallet,
            score,
            totalTx,
            ageMonths,
            hasDefi,
            chainCount
        );

        emit ScoreSubmitted(wallet, score, requestId, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function authorizeCaller(address caller) external onlyOwner {
        if (caller == address(0)) revert SkoreOracle__ZeroAddress();
        authorizedCallers[caller] = true;
        emit CallerAuthorized(caller);
    }

    function revokeCaller(address caller) external onlyOwner {
        authorizedCallers[caller] = false;
        emit CallerRevoked(caller);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function isProcessed(bytes32 requestId) external view returns (bool) {
        return processedRequests[requestId];
    }
}