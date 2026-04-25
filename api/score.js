require("dotenv").config();
const express = require("express");
const cors = require("cors");
const { ethers } = require("ethers");

const app = express();
app.use(cors());
app.use(express.json());

/*//////////////////////////////////////////////////////////////
                         CONFIGURATION
//////////////////////////////////////////////////////////////*/

const ALCHEMY_BASE_URL = `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`;
const ALCHEMY_POLYGON_URL = `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`;
const ALCHEMY_BASE_CHAIN_URL = `https://base-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`;
const BASE_SEPOLIA_RPC = `https://base-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`;

const ORACLE_ABI = [
  "function submitScore(address wallet, uint256 score, uint256 totalTx, uint256 ageMonths, bool hasDefi, uint8 chainCount, bytes32 requestId) external"
];

const SBT_ABI = [
  "function hasScore(address wallet) external view returns (bool)",
  "function getScore(address wallet) external view returns (tuple(uint256 score, uint256 lastUpdated, uint256 totalTransactions, uint256 walletAgeMonths, bool hasDefiHistory, uint8 chainCount))",
  "function getScoreLabel(address wallet) external view returns (string)"
];

const DEFI_PROTOCOLS = [
  "0x7d2768de32b0b80b7a3454c06bdac94a69ddc7a9",
  "0x87870bca3f3fd6335c3f4ce8392d69350b4fa4e2",
  "0x3d9819210a31b4961b30ef54be2aed79b9c9cd3b",
  "0x1111111254fb6c44bac0bed2854e76f90643097d",
  "0x68b3465833fb72a70ecdf485e0e4c7bd8665fc45",
];

/*//////////////////////////////////////////////////////////////
                      SCORING ALGORITHM
//////////////////////////////////////////////////////////////*/

function computeScore(walletData) {
  let score = 300;
  const { ageMonths, totalTransactions, monthlyTxAverage, hasDefiHistory,
    liquidationCount, uniqueTokens, activeChains, totalVolumeUSD } = walletData;

  score += Math.min(ageMonths, 100);

  if (monthlyTxAverage >= 20) score += 150;
  else if (monthlyTxAverage >= 10) score += 100;
  else if (monthlyTxAverage >= 5) score += 70;
  else if (monthlyTxAverage >= 2) score += 40;
  else if (monthlyTxAverage >= 1) score += 20;

  if (hasDefiHistory) {
    score += 100;
    if (totalTransactions > 500) score += 50;
  }

  if (totalVolumeUSD >= 100000) score += 100;
  else if (totalVolumeUSD >= 10000) score += 70;
  else if (totalVolumeUSD >= 1000) score += 40;
  else if (totalVolumeUSD >= 100) score += 20;

  if (uniqueTokens >= 10) score += 50;
  else if (uniqueTokens >= 5) score += 30;
  else if (uniqueTokens >= 2) score += 15;

  if (activeChains >= 3) score += 100;
  else if (activeChains >= 2) score += 50;

  score -= Math.min(liquidationCount * 50, 150);

  return Math.max(300, Math.min(850, Math.round(score)));
}

function getLabel(score) {
  if (score >= 750) return "Excellent";
  if (score >= 670) return "Good";
  if (score >= 580) return "Fair";
  if (score >= 500) return "Poor";
  return "Very Poor";
}

/*//////////////////////////////////////////////////////////////
                      WALLET DATA FETCHER
//////////////////////////////////////////////////////////////*/

async function fetchWalletData(walletAddress) {
  console.log(`Fetching data for wallet: ${walletAddress}`);
  try {
    const [ethData, polygonData, baseData] = await Promise.allSettled([
      fetchChainData(walletAddress, ALCHEMY_BASE_URL, "ethereum"),
      fetchChainData(walletAddress, ALCHEMY_POLYGON_URL, "polygon"),
      fetchChainData(walletAddress, ALCHEMY_BASE_CHAIN_URL, "base"),
    ]);

    let totalTransactions = 0;
    let firstTxTimestamp = Date.now();
    let hasDefiHistory = false;
    let uniqueTokensSet = new Set();
    let activeChains = 0;
    let totalVolumeUSD = 0;
    let liquidationCount = 0;

    for (const chainResult of [ethData, polygonData, baseData]) {
      if (chainResult.status === "fulfilled" && chainResult.value) {
        const data = chainResult.value;
        totalTransactions += data.txCount;
        if (data.txCount > 0) activeChains++;
        if (data.firstTxTimestamp < firstTxTimestamp) firstTxTimestamp = data.firstTxTimestamp;
        if (data.hasDefiInteraction) hasDefiHistory = true;
        data.tokens.forEach(t => uniqueTokensSet.add(t));
        totalVolumeUSD += data.volumeUSD;
        liquidationCount += data.liquidations;
      }
    }

    const ageMs = Date.now() - firstTxTimestamp;
    const ageMonths = Math.floor(ageMs / (1000 * 60 * 60 * 24 * 30));
    const monthlyTxAverage = ageMonths > 0 ? totalTransactions / ageMonths : totalTransactions;

    return { ageMonths, totalTransactions, monthlyTxAverage, hasDefiHistory,
      liquidationCount, uniqueTokens: uniqueTokensSet.size, activeChains, totalVolumeUSD };

  } catch (error) {
    console.error("Error fetching wallet data:", error);
    return { ageMonths: 0, totalTransactions: 0, monthlyTxAverage: 0,
      hasDefiHistory: false, liquidationCount: 0, uniqueTokens: 0, activeChains: 0, totalVolumeUSD: 0 };
  }
}

async function fetchChainData(walletAddress, alchemyUrl, chainName) {
  try {
    const provider = new ethers.JsonRpcProvider(alchemyUrl);
    const txCount = await provider.getTransactionCount(walletAddress);

    const balanceResponse = await fetch(alchemyUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "alchemy_getTokenBalances", params: [walletAddress] }),
    });
    const balanceData = await balanceResponse.json();
    const tokens = balanceData.result?.tokenBalances
      ?.filter(t => t.tokenBalance !== "0x0000000000000000000000000000000000000000000000000000000000000000")
      ?.map(t => t.contractAddress) || [];

    const transferResponse = await fetch(alchemyUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0", id: 2, method: "alchemy_getAssetTransfers",
        params: [{ fromAddress: walletAddress, category: ["external", "erc20"], maxCount: "0x3e8", order: "asc" }],
      }),
    });
    const transferData = await transferResponse.json();
    const transfers = transferData.result?.transfers || [];

    let firstTxTimestamp = Date.now();
    if (transfers.length > 0 && transfers[0].blockNum) {
      const block = await provider.getBlock(parseInt(transfers[0].blockNum, 16));
      if (block) firstTxTimestamp = block.timestamp * 1000;
    }

    const hasDefiInteraction = transfers.some(tx =>
      DEFI_PROTOCOLS.some(p => tx.to?.toLowerCase() === p.toLowerCase())
    );

    const volumeUSD = transfers.reduce((acc, tx) => {
      if (tx.asset === "ETH" && tx.value) return acc + (tx.value * 2000);
      return acc;
    }, 0);

    console.log(`${chainName}: ${txCount} txs, ${tokens.length} tokens, defi: ${hasDefiInteraction}`);
    return { txCount, firstTxTimestamp, hasDefiInteraction, tokens, volumeUSD, liquidations: 0 };

  } catch (error) {
    console.error(`Error fetching ${chainName} data:`, error.message);
    return { txCount: 0, firstTxTimestamp: Date.now(), hasDefiInteraction: false, tokens: [], volumeUSD: 0, liquidations: 0 };
  }
}

/*//////////////////////////////////////////////////////////////
                    BLOCKCHAIN INTERACTION
//////////////////////////////////////////////////////////////*/

async function submitScoreToChain(walletAddress, score, walletData) {
  const provider = new ethers.JsonRpcProvider(BASE_SEPOLIA_RPC);
  const oracleWallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const oracleContract = new ethers.Contract(process.env.SKORE_ORACLE_ADDRESS, ORACLE_ABI, oracleWallet);

  const requestId = ethers.keccak256(ethers.toUtf8Bytes(`${walletAddress}-${Date.now()}`));

  const tx = await oracleContract.submitScore(
    walletAddress, score, walletData.totalTransactions, walletData.ageMonths,
    walletData.hasDefiHistory, Math.min(walletData.activeChains, 255), requestId,
    { gasLimit: 500000 }
  );

  await tx.wait();
  console.log(`Score submitted on-chain. Tx: ${tx.hash}`);
  return tx.hash;
}

/*//////////////////////////////////////////////////////////////
                         API ROUTES
//////////////////////////////////////////////////////////////*/

app.get("/", (req, res) => {
  res.json({
    name: "Skoré Protocol API",
    version: "1.0.0",
    description: "Decentralised credit scoring for unbanked Africans",
    status: "live",
    network: "Base Sepolia",
    contracts: {
      SkoreSBT: "0xCC0B4686de40Ff5ae1e0B8d58Da9175e9090610D",
      SkoreOracle: "0xF77cEEa40d44C4b7c5dFF7DD31dc0E281FaFeE55"
    },
    endpoints: {
      health: "GET /health",
      getScore: "GET /score/:wallet",
      requestScore: "POST /score",
      testScore: "POST /score/test"
    },
    example: "GET /score/0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
  });
});

app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "Skore API" });
});

app.post("/score/test", async (req, res) => {
  const { wallet } = req.body;
  if (!wallet || !ethers.isAddress(wallet)) {
    return res.status(400).json({ error: "Invalid wallet address" });
  }
  try {
    const walletData = await fetchWalletData(wallet);
    const score = computeScore(walletData);
    return res.json({ success: true, wallet, score, label: getLabel(score), walletData });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

app.get("/score/:wallet", async (req, res) => {
  const { wallet } = req.params;
  if (!ethers.isAddress(wallet)) {
    return res.status(400).json({ error: "Invalid wallet address" });
  }
  try {
    const provider = new ethers.JsonRpcProvider(BASE_SEPOLIA_RPC);
    const sbtContract = new ethers.Contract(process.env.SKORE_SBT_ADDRESS, SBT_ABI, provider);
    const hasScore = await sbtContract.hasScore(wallet);

    if (!hasScore) {
      return res.json({ wallet, hasScore: false, message: "No score found. POST /score to generate one." });
    }

    const scoreData = await sbtContract.getScore(wallet);
    const label = await sbtContract.getScoreLabel(wallet);

    return res.json({
      wallet,
      hasScore: true,
      score: Number(scoreData.score),
      label,
      lastUpdated: new Date(Number(scoreData.lastUpdated) * 1000).toISOString(),
      totalTransactions: Number(scoreData.totalTransactions),
      walletAgeMonths: Number(scoreData.walletAgeMonths),
      hasDefiHistory: scoreData.hasDefiHistory,
      chainCount: Number(scoreData.chainCount),
    });

  } catch (error) {
    console.error("Fetch score error:", error);
    return res.status(500).json({ error: error.message });
  }
});

app.post("/score", async (req, res) => {
  const { wallet } = req.body;
  if (!wallet || !ethers.isAddress(wallet)) {
    return res.status(400).json({ error: "Invalid wallet address" });
  }
  try {
    console.log(`\nScoring wallet: ${wallet}`);
    const walletData = await fetchWalletData(wallet);
    console.log("Wallet data:", walletData);
    const score = computeScore(walletData);
    console.log(`Computed score: ${score}`);
    const txHash = await submitScoreToChain(wallet, score, walletData);
    return res.json({ success: true, wallet, score, label: getLabel(score), walletData, txHash });
  } catch (error) {
    console.error("Scoring error:", error);
    return res.status(500).json({ error: "Scoring failed", details: error.message });
  }
});

/*//////////////////////////////////////////////////////////////
                         START SERVER
//////////////////////////////////////////////////////////////*/

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Skore API running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`Score endpoint: POST http://localhost:${PORT}/score`);
});

module.exports = app;