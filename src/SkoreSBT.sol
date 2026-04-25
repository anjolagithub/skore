// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SkoreSBT
 * @author Skoré Protocol
 * @notice Soulbound credit score token — one per wallet, non-transferable
 * @dev Score ranges from 300 (poor) to 850 (excellent)
 *      Inspired by Cyfrin Updraft best practices
 *      v2 will integrate Chainlink Functions for decentralised scoring
 */
contract SkoreSBT is ERC721, Ownable {

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error SkoreSBT__Soulbound();
    error SkoreSBT__AlreadyHasScore();
    error SkoreSBT__NoScoreFound();
    error SkoreSBT__InvalidScore();
    error SkoreSBT__NotOracle();
    error SkoreSBT__ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MIN_SCORE = 300;
    uint256 public constant MAX_SCORE = 850;

    address public oracle;
    uint256 private s_tokenCounter;

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct ScoreData {
        uint256 score;
        uint256 lastUpdated;
        uint256 totalTransactions;
        uint256 walletAgeMonths;
        bool hasDefiHistory;
        uint8 chainCount;
    }

    /*//////////////////////////////////////////////////////////////
                                MAPPINGS
    //////////////////////////////////////////////////////////////*/

    /// @notice wallet address → token ID
    mapping(address => uint256) private s_walletToTokenId;

    /// @notice token ID → score data
    mapping(uint256 => ScoreData) private s_scores;

    /// @notice wallet address → has token
    mapping(address => bool) private s_hasToken;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Kwala Workflow 2 listens to this
    event ScoreIssued(
        address indexed wallet,
        uint256 indexed tokenId,
        uint256 score,
        uint256 timestamp
    );

    /// @notice Kwala Workflow 3 and 4 listen to this
    event ScoreUpdated(
        address indexed wallet,
        uint256 indexed tokenId,
        uint256 oldScore,
        uint256 newScore,
        uint256 timestamp
    );

    /// @notice Kwala Workflow 1 listens to this
    event ScoreRequested(
        address indexed wallet,
        uint256 timestamp
    );

    event OracleUpdated(
        address indexed oldOracle,
        address indexed newOracle
    );

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOracle() {
        if (msg.sender != oracle) revert SkoreSBT__NotOracle();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _oracle) ERC721("Skore Credit Token", "SKORE") Ownable(msg.sender) {
        if (_oracle == address(0)) revert SkoreSBT__ZeroAddress();
        oracle = _oracle;
        s_tokenCounter = 0;
    }

   /*//////////////////////////////////////////////////////////////
                    SOULBOUND — BLOCK ALL TRANSFERS
//////////////////////////////////////////////////////////////*/

/**
 * @dev Override _update which is called by all transfer functions
 * This is the correct OZ v5 pattern for soulbound tokens
 * Allows minting (from == address(0)) but blocks all transfers
 */
function _update(
    address to,
    uint256 tokenId,
    address auth
) internal override returns (address) {
    address from = _ownerOf(tokenId);
    if (from != address(0)) {
        revert SkoreSBT__Soulbound();
    }
    return super._update(to, tokenId, auth);
}

/**
 * @dev Block approvals entirely — nothing to approve on a soulbound token
 */
function approve(address, uint256) public pure override {
    revert SkoreSBT__Soulbound();
}

function setApprovalForAll(address, bool) public pure override {
    revert SkoreSBT__Soulbound();
}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Any wallet can request their credit score
     * @dev Emits ScoreRequested — Kwala Workflow 1 picks this up
     *      and calls our scoring API which then calls issueScore()
     */
    function requestScore() external {
        emit ScoreRequested(msg.sender, block.timestamp);
    }

    /**
     * @notice Oracle issues a new score to a wallet
     * @dev Called by our trusted oracle after computing score off-chain
     *      Mints soulbound token if wallet doesn't have one
     * @param wallet The wallet to score
     * @param score The computed score (300-850)
     * @param totalTx Total lifetime transactions
     * @param ageMonths Wallet age in months
     * @param hasDefi Whether wallet has DeFi history
     * @param chainCount Number of chains active on
     */
    function issueScore(
        address wallet,
        uint256 score,
        uint256 totalTx,
        uint256 ageMonths,
        bool hasDefi,
        uint8 chainCount
    ) external onlyOracle {
        if (wallet == address(0)) revert SkoreSBT__ZeroAddress();
        if (score < MIN_SCORE || score > MAX_SCORE) revert SkoreSBT__InvalidScore();

        if (s_hasToken[wallet]) {
            // Update existing score
            uint256 tokenId = s_walletToTokenId[wallet];
            uint256 oldScore = s_scores[tokenId].score;

            s_scores[tokenId] = ScoreData({
                score: score,
                lastUpdated: block.timestamp,
                totalTransactions: totalTx,
                walletAgeMonths: ageMonths,
                hasDefiHistory: hasDefi,
                chainCount: chainCount
            });

            emit ScoreUpdated(wallet, tokenId, oldScore, score, block.timestamp);
        } else {
            // Mint new soulbound token
            uint256 tokenId = s_tokenCounter++;
            s_hasToken[wallet] = true;
            s_walletToTokenId[wallet] = tokenId;

            s_scores[tokenId] = ScoreData({
                score: score,
                lastUpdated: block.timestamp,
                totalTransactions: totalTx,
                walletAgeMonths: ageMonths,
                hasDefiHistory: hasDefi,
                chainCount: chainCount
            });

            _mint(wallet, tokenId);

            emit ScoreIssued(wallet, tokenId, score, block.timestamp);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setOracle(address newOracle) external onlyOwner {
        if (newOracle == address(0)) revert SkoreSBT__ZeroAddress();
        emit OracleUpdated(oracle, newOracle);
        oracle = newOracle;
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getScore(address wallet) external view returns (ScoreData memory) {
        if (!s_hasToken[wallet]) revert SkoreSBT__NoScoreFound();
        uint256 tokenId = s_walletToTokenId[wallet];
        return s_scores[tokenId];
    }

    function hasScore(address wallet) external view returns (bool) {
        return s_hasToken[wallet];
    }

    function getTokenCounter() external view returns (uint256) {
        return s_tokenCounter;
    }

    function getScoreLabel(address wallet) external view returns (string memory) {
        if (!s_hasToken[wallet]) revert SkoreSBT__NoScoreFound();
        uint256 tokenId = s_walletToTokenId[wallet];
        uint256 score = s_scores[tokenId].score;

        if (score >= 750) return "Excellent";
        if (score >= 670) return "Good";
        if (score >= 580) return "Fair";
        if (score >= 500) return "Poor";
        return "Very Poor";
    }

   function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        ownerOf(tokenId);
        return string(abi.encodePacked(
            "https://skore.protocol/token/",
            _toString(tokenId)
        ));
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) { digits++; temp /= 10; }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(buffer);
    }
}