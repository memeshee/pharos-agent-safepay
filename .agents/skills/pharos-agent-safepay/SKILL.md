---
name: pharos-agent-safepay
description: Safe payment vault skill for Pharos AI agents. Use when deploying an agent wallet, setting agent payment policy, approving recipients, setting daily spending limits, depositing PHRS, paying PHRS or ERC20 tokens, querying remaining agent budget, or reading payment receipts on Pharos Atlantic.
license: MIT
metadata:
  author: kiter
  version: "1.0.0"
---

# Pharos Agent SafePay Skill

This skill lets an AI agent transact on Pharos through a bounded policy vault instead of using an unrestricted private key directly. The owner configures an agent executor, allowed recipients, and daily limits. The agent can then execute PHRS or ERC20 payments and produce on-chain receipt logs.

## Network Defaults

Read network data from `assets/networks.json`.

- Default network: `atlantic`
- Chain ID: `688689`
- Native token: `PHRS`
- RPC: `https://atlantic.dplabs-internal.com`
- Explorer: `https://atlantic.pharosscan.xyz`

## Prerequisites

- Foundry installed: `cast --version` and `forge --version`
- Owner private key exported as `PRIVATE_KEY`
- Agent private key exported as `AGENT_PRIVATE_KEY` when executing payments as the agent
- Never paste, log, or commit private keys

## Write Operation Prechecks

Before any `forge script` or `cast send` operation:

1. Confirm the target network is Pharos Atlantic unless the user explicitly chooses another Pharos network.
2. Derive the sender address with `cast wallet address --private-key $PRIVATE_KEY` or `$AGENT_PRIVATE_KEY`.
3. Check sender PHRS balance with `cast balance <sender> --rpc-url <rpc> --ether`.
4. Validate every address is `0x` plus 40 hex characters.
5. For payment operations, call `remainingToday(token)` and confirm the requested amount is within budget.
6. For payment operations, use a unique `paymentId` and never reuse it after a failed or successful attempt until the receipt has been checked.

## Capability Index

| User Need | Capability | Detailed Instructions |
| --- | --- | --- |
| Deploy SafePay vault / create agent wallet / policy wallet for agent | `forge script` deploy | `references/deploy.md` |
| Configure agent executor / change agent wallet signer | `cast send setAgent(address)` | `references/configure.md#set-agent-executor` |
| Approve or block payment recipient / allowlist recipient | `cast send setRecipientAllowed(address,bool)` | `references/configure.md#set-recipient-allowlist` |
| Set PHRS or token daily limit / cap agent spending | `cast send setDailyLimit(address,uint256)` | `references/configure.md#set-daily-limit` |
| Deposit PHRS into SafePay | `cast send depositNative() --value` | `references/pay.md#deposit-native-phrs` |
| Pay PHRS from agent wallet / execute safe native payment | `cast send payNative(address,uint256,bytes32,bytes32)` | `references/pay.md#execute-native-payment` |
| Pay USDC or ERC20 from agent wallet | `cast send payERC20(address,address,uint256,bytes32,bytes32)` | `references/pay.md#execute-erc20-payment` |
| Check remaining budget / daily spend left | `cast call remainingToday(address)` | `references/pay.md#check-remaining-budget` |
| Show payment receipts / audit agent payments | `cast logs PaymentExecuted` | `references/receipts.md` |
| Verify SafePay contract | `forge verify-contract` | `references/deploy.md#verify-contract` |

## Safety Rules

- Never execute a payment to a recipient that is not allowed by `allowedRecipients(recipient)`.
- Never bypass `remainingToday(token)` before a payment.
- Never expose `PRIVATE_KEY` or `AGENT_PRIVATE_KEY` in generated files.
- Use `address(0)` as the token address for native PHRS in all read/write commands.
- Use base units for all limits and ERC20 payments. PHRS has 18 decimals. Atlantic USDC has 6 decimals.
- If a command reverts, inspect the exact revert reason and map it through the reference file before retrying.

## Reference Files

- `references/deploy.md`: deploy and verify the vault.
- `references/configure.md`: set agent, recipient allowlist, pause state, daily limits.
- `references/pay.md`: deposit, execute payments, check budget.
- `references/receipts.md`: query and interpret payment logs.
- `assets/networks.json`: Pharos network metadata.
- `assets/tokens.json`: known token metadata.
