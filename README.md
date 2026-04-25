# Skoré 📊

> Decentralized credit scoring protocol for on-chain wallets, powered by Kwala

Built for the **Build with Kwala Hackathon — 2026**

---

## 🚀 Overview

Skoré is a decentralized credit scoring protocol that analyzes on-chain wallet activity and assigns a **verifiable credit score (300–850)**.

Each score is issued as a **non-transferable Soulbound Token (SBT)**, giving users a portable, on-chain financial identity.

---

## 🌍 The Problem

Over **1.4 billion people globally are unbanked**, with a large percentage in Africa.

### Key challenges:
- No formal credit history
- Limited access to loans and financial services
- Existing DeFi platforms lack usable credit scoring systems
- Lenders cannot reliably assess borrower risk

---

## 💡 The Solution

Skoré creates a **trust layer for Web3 finance**:

- Analyze wallet behavior on-chain
- Generate a credit score (300–850)
- Mint a **Soulbound Token (SBT)** representing that score
- Enable lenders to verify creditworthiness instantly

> A user's wallet becomes their financial identity.

---

## ⚡ Key Features

- On-chain credit scoring
- Soulbound identity (non-transferable NFT)
- Real-time score updates
- Automated workflows powered by Kwala
- Lender-ready infrastructure

---

## 🏗 Architecture
User submits wallet
↓
Smart Contract emits ScoreRequested
↓
Kwala Workflow triggers
↓
Scoring API processes wallet data
↓
Score computed (300–850)
↓
Oracle updates smart contract
↓
Soulbound Token minted/updated
↓
Kwala sends Telegram notification


---

## 🧠 Smart Contracts

### 1. `SkoreSBT.sol`
- ERC721 Soulbound Token
- Stores user credit score
- Non-transferable (identity-bound)

### 2. `SkoreOracle.sol`
- Receives score from API
- Updates SBT
- Emits events for Kwala

---

## 🔁 Kwala Integration (Core Highlight)

Kwala powers the entire automation layer through **event-driven workflows**.

### Workflows

| Workflow | Trigger | Action |
|----------|--------|--------|
| Score Request | `ScoreRequested` | Call scoring API |
| Score Issued | `ScoreIssued` | Notify user (Telegram) |
| Low Score Alert | Score < 500 | Notify user with insights |
| High Score Alert | Score > 750 | Notify eligibility for loans |
| Rescore Trigger | New wallet activity | Recalculate score |

> No backend servers required — Kwala handles orchestration.

---

## 📊 Scoring Algorithm

Score range: **300 – 850**

### Components:

- **Wallet Age** (+100 max)  
  → Older wallets = higher trust  

- **Transaction Consistency** (+150 max)  
  → Regular activity rewarded  

- **DeFi Participation** (+150 max)  
  → Lending/borrowing activity  

- **Volume Score** (+100 max)  
  → Total transaction value  

- **Token Diversity** (+50 max)  
  → Variety of assets held  

- **Cross-chain Activity** (+100 max)  
  → Multi-chain usage  

- **Liquidation Penalty** (-150 max)  
  → Penalizes risky behavior  

---

## 📁 Project Structure
skore/
├── src/
│ ├── SkoreSBT.sol
│ └── SkoreOracle.sol
├── test/
│ └── Skore.t.sol
├── script/
│ └── Deploy.s.sol
├── api/
│ └── score.js
├── frontend/
│ └── index.html
├── kwala/
│ ├── workflow1-score-requested.yaml
│ ├── workflow2-score-issued.yaml
│ ├── workflow3-low-score-alert.yaml
│ ├── workflow4-high-score-alert.yaml
│ └── workflow5-rescore-trigger.yaml
├── .env
├── foundry.toml
└── README.md


---

## 🛠 Setup

### Prerequisites
- Foundry
- Node.js
- Alchemy API key

### Installation

```
git clone https://github.com/your-repo/skore
cd skore

forge install OpenZeppelin/openzeppelin-contracts
forge install foundry-rs/forge-std

🔗 How It Works (End-to-End)
User submits wallet address
Contract emits ScoreRequested
Kwala triggers scoring API
API fetches wallet data via Alchemy
Score is calculated
Oracle updates contract
SBT is minted/updated
User receives Telegram notification




💼 Business Model
Target Users
Unbanked individuals in Africa
DeFi-native users without formal credit history
Fintech lenders
Value Proposition
Enables lending without traditional credit bureaus
Reduces default risk
Unlocks new financial access
Monetization
API access fees for lenders
Credit scoring queries
Premium analytics

🏁 Summary

Skoré transforms on-chain activity into trust.

A wallet is no longer just an address —
it becomes a verifiable financial identity.
