# Ionic Escrow

A next-generation DAO governance platform built on Stacks blockchain that revolutionizes voting mechanisms through dynamic time-weighted ionic bonding.

## Overview

Ionic Escrow implements a novel molecular bonding model where governance tokens form ionic pairs with project-specific utility tokens, creating graduated voting weights based on bond strength and duration. This innovative approach moves beyond traditional vote-escrow systems to provide more nuanced and flexible governance participation.

## Key Features

### 🔗 Dynamic Ionic Bonding
- Time-weighted token bonding system
- Bond strength increases with duration
- Flexible bonding amounts with configurable minimums
- Gradual accumulation of voting power over time

### 🗳️ Weighted Voting System
- Voting power calculated from: bond amount × duration multiplier × reputation score
- One vote per user per proposal
- Transparent vote counting and proposal execution
- Time-bounded voting periods for structured decision-making

### 🏆 Reputation Layer
- Tracks individual voting accuracy and participation
- Reputation score adjusts voting weight (100 = 1x baseline)
- Incentivizes quality decision-making
- Historical decision quality tracking

### 📋 Proposal Management
- Community-driven proposal creation
- Minimum bond requirement to prevent spam
- Automated proposal lifecycle (active → voting → execution)
- Clear pass/fail determination based on weighted votes

## Smart Contract Functions

### Public Functions

#### `create-bond (amount uint)`
Lock governance tokens to participate in voting. Increases existing bonds or creates new ones.

**Parameters:**
- `amount`: Number of tokens to bond (must meet minimum requirement)

**Returns:** `(ok true)` on success

**Example:**
```clarity
(contract-call? .ionic-escrow create-bond u5000)
```

#### `create-proposal (title (string-ascii 256)) (description (string-ascii 1024))`
Submit a new governance proposal. Requires minimum bond amount.

**Parameters:**
- `title`: Proposal title (max 256 characters)
- `description`: Detailed description (max 1024 characters)

**Returns:** `(ok proposal-id)` with the new proposal ID

**Example:**
```clarity
(contract-call? .ionic-escrow create-proposal 
  "Treasury Diversification" 
  "Proposal to allocate 20% of treasury into BTC")
```

#### `cast-vote (proposal-id uint) (vote-choice bool)`
Cast a weighted vote on an active proposal. Vote weight is calculated based on bond amount, duration, and reputation.

**Parameters:**
- `proposal-id`: ID of the proposal to vote on
- `vote-choice`: `true` for yes, `false` for no

**Returns:** `(ok true)` on success

**Example:**
```clarity
(contract-call? .ionic-escrow cast-vote u1 true)
```

#### `execute-proposal (proposal-id uint)`
Finalize a proposal after the voting period ends. Determines pass/fail based on vote totals.

**Parameters:**
- `proposal-id`: ID of the proposal to execute

**Returns:** `(ok true/false)` indicating if proposal passed

**Example:**
```clarity
(contract-call? .ionic-escrow execute-proposal u1)
```

#### `update-reputation (account principal) (accurate bool)`
Update a user's reputation score based on voting accuracy. Owner-only function.

**Parameters:**
- `account`: Principal address to update
- `accurate`: `true` if vote was accurate, `false` otherwise

**Returns:** `(ok true)` on success

### Read-Only Functions

#### `get-proposal (proposal-id uint)`
Retrieve full proposal details including vote counts and status.

#### `get-bond (account principal)`
Get bonding information for a specific account.

#### `get-reputation (account principal)`
Retrieve reputation data including score and voting history.

#### `calculate-voting-weight (account principal)`
Calculate current voting weight for an account based on bond, duration, and reputation.

#### `get-proposal-status (proposal-id uint)`
Get current status of a proposal (active, vote counts, execution status).

#### `has-voted (proposal-id uint) (voter principal)`
Check if a specific user has already voted on a proposal.

## Voting Weight Calculation

Voting weight is dynamically calculated using the formula:

```
weight = (bond_amount × (1 + duration/10) × reputation_score) / 10000
```

Where:
- `bond_amount`: Total tokens bonded by the user
- `duration`: Blocks since bond creation (increases weight over time)
- `reputation_score`: User's reputation (100 = baseline, can be higher or lower)

This ensures that long-term participants with good track records have proportionally higher influence.

## Error Codes

- `u100`: Owner-only operation
- `u101`: Proposal or data not found
- `u102`: User already voted on this proposal
- `u103`: Proposal voting period has expired
- `u104`: Proposal is not active or already executed
- `u105`: Insufficient bond amount
- `u106`: Invalid amount provided

## Future Enhancements

The current implementation provides core governance functionality. Planned enhancements include:

- Cross-chain governance through bridge validators
- Zero-knowledge proof integration for privacy
- Prediction market integration
- Automated treasury rebalancing
- Natural language processing for proposals
- Advanced analytics dashboards
- Multi-stage execution with rollback mechanisms
- Domain-specific delegate voting
