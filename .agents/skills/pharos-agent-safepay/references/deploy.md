# Deploy Instructions

Use this file when the user wants to deploy or verify an AgentSafePayVault.

## Deploy SafePay Vault

### Overview

Deploys `AgentSafePayVault` on Pharos Atlantic. The deployer becomes owner. The optional `AGENT_ADDRESS` environment variable sets the initial payment executor.

### Command Template

```bash
export RPC=https://atlantic.dplabs-internal.com
export OWNER=$(cast wallet address --private-key $PRIVATE_KEY)
export AGENT_ADDRESS=0xAgentAddress

forge script script/DeployAgentSafePayVault.s.sol:DeployAgentSafePayVault \
  --rpc-url $RPC \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `PRIVATE_KEY` | env | Yes | Owner private key used for deployment |
| `AGENT_ADDRESS` | address | No | Agent executor address, or zero address if omitted |
| `RPC` | URL | Yes | Pharos Atlantic RPC URL |

### Output Parsing

| Field | Description |
| --- | --- |
| `AgentSafePayVault:` | Deployed vault address |
| `Owner:` | Owner address that can configure policy |
| `Agent:` | Agent executor allowed to run payments |

### Error Handling

| Error | Cause | Fix |
| --- | --- | --- |
| `PRIVATE_KEY not set` | Missing owner key | Export `PRIVATE_KEY` in the current shell |
| `insufficient funds` | Owner lacks PHRS for gas | Fund owner from the Pharos faucet |
| `connection refused` | Missing or bad RPC URL | Use `https://atlantic.dplabs-internal.com` |

> Agent Guidelines:
> 1. Run Write Operation Prechecks from `SKILL.md`.
> 2. Confirm `cast chain-id --rpc-url $RPC` returns `688689`.
> 3. Deploy with `forge script`.
> 4. Save the vault address and show `<explorerUrl>/address/<vault>`.
> 5. Recommend setting recipients and daily limits before funding with meaningful amounts.

## Verify Contract

### Command Template

```bash
forge verify-contract <vault_address> src/AgentSafePayVault.sol:AgentSafePayVault \
  --chain-id 688689 \
  --verifier-url https://api.socialscan.io/pharos-atlantic-testnet/v1/explorer/command_api/contract \
  --verifier blockscout \
  --constructor-args $(cast abi-encode "constructor(address)" <agent_address>)
```

### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `vault_address` | address | Yes | Deployed vault address |
| `agent_address` | address | Yes | Constructor argument used at deploy, or zero address |

### Error Handling

| Error | Cause | Fix |
| --- | --- | --- |
| `contract not found` | Explorer has not indexed deployment | Wait 10-20 seconds and retry |
| `constructor arguments mismatch` | Wrong agent address encoded | Recheck deploy logs |
| `verification failed` | Compiler settings mismatch | Use this repo's `foundry.toml` settings |
