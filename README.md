# Pharos Agent SafePay

Pharos Agent SafePay is a builder skill for creating bounded payment wallets for AI agents on Pharos.

The product is the Skill. The Solidity vault is the on-chain tool that the Skill teaches agents to deploy, configure, fund, use, and audit.

Instead of giving an agent unrestricted wallet authority, a builder deploys a SafePay vault, funds it, and configures policy:

- which address is allowed to act as the agent executor
- which recipients the agent can pay
- how much the agent can spend per token per day
- whether payments are currently paused
- how to query on-chain payment receipts

The result is a reusable payment primitive for agent builders. Any Pharos agent that needs to pay for APIs, data, compute, services, invoices, or task settlement can call this skill and transact through explicit policy.

## What This Builds

This repo contains two connected artifacts:

1. **A Solidity policy vault**
   - `AgentSafePayVault` holds PHRS or ERC20 tokens.
   - Owner configures payment policy.
   - Agent executor can pay only allowed recipients within daily limits.
   - Each payment uses a unique `paymentId` and emits a `PaymentExecuted` receipt.

2. **A Pharos Skill bundle**
   - `.agents/skills/pharos-agent-safepay/SKILL.md` is the agent entrypoint.
   - References teach agents exact `forge` and `cast` commands.
   - Assets define Pharos Atlantic network and token metadata.
   - A validator checks the skill package before publishing.

This is intentionally CLI-native. It is designed for agents and builders first, not for a web dashboard or one-off dApp.

## Why Builders Use It

AI agents that can transact need constraints. A normal private key can spend everything it controls. SafePay narrows that authority without adding a backend custody service.

Common builder use cases:

- x402 clients that need capped API spending
- trading or data agents that need pay-per-call budgets
- creator or service agents that pay approved vendors
- treasury bots that should never exceed a daily allowance
- agents that need visible on-chain payment receipts
- teams that want agent payments but need a pause button

## Network Defaults

Default target: Pharos Atlantic Testnet.

| Field | Value |
| --- | --- |
| Chain ID | `688689` |
| RPC | `https://atlantic.dplabs-internal.com` |
| Explorer | `https://atlantic.pharosscan.xyz` |
| Native token | `PHRS` |
| Registry USDC | `0xcfC8330f4BCAB529c625D12781b1C19466A9Fc8B` |
| Registry USDT | `0xE7E84B8B4f39C507499c40B4ac199B050e2882d5` |

The skill stores this metadata in `.agents/skills/pharos-agent-safepay/assets/`.

## Repository Layout

```text
.agents/skills/pharos-agent-safepay/
  SKILL.md                         Agent entrypoint and capability index
  assets/networks.json             Pharos network config
  assets/tokens.json               Known token config
  references/deploy.md             Deploy and verify commands
  references/configure.md          Policy configuration commands
  references/pay.md                Deposit and payment commands
  references/receipts.md           Receipt query commands
  templates/payment-plan.md.tpl    Payment plan template for agents

src/AgentSafePayVault.sol          SafePay policy vault
script/DeployAgentSafePayVault.s.sol
test/AgentSafePayVault.t.sol
scripts/validate-skill.js
LIVE_PROOF.md                      Latest Pharos Atlantic proof
```

## Contract Model

### Roles

| Role | Permission |
| --- | --- |
| Owner | Configure agent, recipients, limits, pause state, emergency sweep |
| Agent | Execute allowed payments |
| Recipient | Receive payments if allowlisted |

The owner can also execute payments. This is useful for recovery and manual operation.

### Supported Assets

- Native PHRS via `depositNative()` and `payNative(...)`
- ERC20 tokens via direct token transfer into the vault and `payERC20(...)`

Use `address(0)` for native PHRS in budget reads and policy settings.

### Payment Policy

A payment succeeds only when all conditions are true:

- vault is not paused
- caller is owner or configured agent
- recipient is allowlisted
- amount is non-zero
- `paymentId` has not been used before
- daily remaining budget for the token is sufficient
- token/native transfer succeeds

Every successful payment emits:

```solidity
PaymentExecuted(
  bytes32 paymentId,
  address token,
  address recipient,
  address operator,
  uint256 amount,
  uint256 day,
  uint256 spentAfter,
  bytes32 memoHash
)
```

`memoHash` should be a hash of an invoice id, task id, or off-chain memo. The contract stores the hash, not the plaintext memo.

## Install

Foundry is required.

```bash
forge --version
cast --version
```

Install the local test dependency if it is not already present:

```bash
forge install foundry-rs/forge-std --no-git --shallow
```

Run the local checks:

```bash
forge test
forge build
node scripts/validate-skill.js
```

## Environment

Copy the example file:

```bash
cp .env.example .env
```

Export variables in your shell. Do not commit real keys.

```bash
export RPC=https://atlantic.dplabs-internal.com
export PRIVATE_KEY=<owner-private-key>
export AGENT_PRIVATE_KEY=<agent-private-key>
export AGENT_ADDRESS=$(cast wallet address --private-key "$AGENT_PRIVATE_KEY")
```

Verify the network:

```bash
cast chain-id --rpc-url "$RPC"
```

Expected:

```text
688689
```

## Deploy A SafePay Vault

```bash
forge script script/DeployAgentSafePayVault.s.sol:DeployAgentSafePayVault \
  --rpc-url "$RPC" \
  --private-key "$PRIVATE_KEY" \
  --broadcast
```

Save the deployed vault:

```bash
export VAULT_ADDRESS=<deployed-vault-address>
```

The deployer is the owner. `AGENT_ADDRESS` is read from the environment and can be zero if you want to configure it later.

## Configure Policy

Set or change the agent executor:

```bash
cast send "$VAULT_ADDRESS" "setAgent(address)" "$AGENT_ADDRESS" \
  --private-key "$PRIVATE_KEY" \
  --rpc-url "$RPC"
```

Allow a recipient:

```bash
export RECIPIENT_ADDRESS=<recipient-address>

cast send "$VAULT_ADDRESS" "setRecipientAllowed(address,bool)" "$RECIPIENT_ADDRESS" true \
  --private-key "$PRIVATE_KEY" \
  --rpc-url "$RPC"
```

Set a tiny native PHRS daily limit, here `0.001 PHRS`:

```bash
cast send "$VAULT_ADDRESS" "setDailyLimit(address,uint256)" \
  0x0000000000000000000000000000000000000000 1000000000000000 \
  --private-key "$PRIVATE_KEY" \
  --rpc-url "$RPC"
```

Pause payments:

```bash
cast send "$VAULT_ADDRESS" "setPaused(bool)" true \
  --private-key "$PRIVATE_KEY" \
  --rpc-url "$RPC"
```

## Fund And Pay

Deposit `0.001 PHRS`:

```bash
cast send "$VAULT_ADDRESS" "depositNative()" \
  --value 0.001ether \
  --private-key "$PRIVATE_KEY" \
  --rpc-url "$RPC"
```

Prepare an idempotent payment:

```bash
export PAYMENT_ID=$(cast keccak "demo-payment-001")
export MEMO_HASH=$(cast keccak "SafePay demo payment")
```

Preflight:

```bash
cast call "$VAULT_ADDRESS" "allowedRecipients(address)(bool)" "$RECIPIENT_ADDRESS" --rpc-url "$RPC"
cast call "$VAULT_ADDRESS" "remainingToday(address)(uint256)" \
  0x0000000000000000000000000000000000000000 --rpc-url "$RPC"
cast call "$VAULT_ADDRESS" "usedPaymentIds(bytes32)(bool)" "$PAYMENT_ID" --rpc-url "$RPC"
```

Pay `0.0001 PHRS` as the agent:

```bash
cast send "$VAULT_ADDRESS" "payNative(address,uint256,bytes32,bytes32)" \
  "$RECIPIENT_ADDRESS" 100000000000000 "$PAYMENT_ID" "$MEMO_HASH" \
  --private-key "$AGENT_PRIVATE_KEY" \
  --rpc-url "$RPC"
```

## Query Receipts

```bash
export FROM_BLOCK=<deployment-or-demo-start-block>

cast logs \
  --rpc-url "$RPC" \
  --address "$VAULT_ADDRESS" \
  --from-block "$FROM_BLOCK" \
  --to-block latest \
  "PaymentExecuted(bytes32,address,address,address,uint256,uint256,uint256,bytes32)"
```

Use the event as the on-chain receipt. The transaction hash and vault address can be opened in the Atlantic explorer.

## Using The Skill With An Agent

Point an agent that supports project skills at:

```text
.agents/skills/pharos-agent-safepay/SKILL.md
```

Example prompts:

```text
Deploy a SafePay vault on Pharos Atlantic with my current wallet as owner.
```

```text
Allow 0xRecipient to receive payments and set a 0.001 PHRS daily limit.
```

```text
Pay 0.0001 PHRS from my SafePay vault with memo "data API invoice 001".
```

```text
Show the remaining PHRS budget and the last SafePay receipts.
```

The skill will route the agent to the exact reference file and command template.

## Builder Workflows

### Agent API Payment

1. User gives an agent a task that requires a paid API.
2. Agent checks remaining SafePay budget.
3. Agent pays the approved API recipient.
4. Agent stores the `paymentId` and tx hash as proof.
5. Agent calls the API with the receipt.

### Agent Vendor Payment

1. Owner allowlists a vendor address.
2. Owner sets a daily cap for PHRS or USDC.
3. Agent pays invoices with a hashed memo.
4. Owner audits `PaymentExecuted` logs.

## Security Notes

SafePay narrows agent authority; it does not eliminate key risk.

- Keep owner keys offline or in a safer wallet when possible.
- Use a separate low-value agent executor key.
- Start with tiny limits.
- Allowlist only known recipients.
- Pause immediately if the agent key may be compromised.
- Treat `PaymentExecuted` logs as the audit trail.
- Do not put private keys in `.env` files that will be shared or committed.

## Testing

The test suite covers:

- owner configuration
- non-owner configuration rejection
- native payments
- ERC20 payments
- recipient allowlist enforcement
- duplicate payment id rejection
- daily limit enforcement
- budget reset on a new day
- pause behavior
- owner emergency sweep

Run:

```bash
forge test -vv
```

## Skill Validation

```bash
node scripts/validate-skill.js
```

The validator checks:

- required skill files exist
- `SKILL.md` routes to all references
- Atlantic chain metadata is correct
- token metadata includes PHRS
- no private-key-like values are present in the skill files

## Proof

See `LIVE_PROOF.md` for the latest Pharos Atlantic proof.
