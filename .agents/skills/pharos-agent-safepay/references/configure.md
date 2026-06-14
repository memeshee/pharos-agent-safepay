# Configure Instructions

Use this file when the user wants to configure SafePay policy.

## Set Agent Executor

### Command Template

```bash
cast send <vault_address> "setAgent(address)" <agent_address> \
  --private-key $PRIVATE_KEY \
  --rpc-url https://atlantic.dplabs-internal.com
```

### Output Parsing

Transaction status `1` means the agent was updated. Show `<explorerUrl>/tx/<txHash>`.

> Agent Guidelines:
> 1. Only owner can call this function.
> 2. Confirm `<agent_address>` is the intended executor wallet.
> 3. After success, read `agent()(address)` with `cast call`.

## Set Recipient Allowlist

### Command Template

```bash
cast send <vault_address> "setRecipientAllowed(address,bool)" <recipient_address> <true_or_false> \
  --private-key $PRIVATE_KEY \
  --rpc-url https://atlantic.dplabs-internal.com
```

### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `recipient_address` | address | Yes | Recipient to allow or block |
| `true_or_false` | bool | Yes | `true` to allow, `false` to block |

> Agent Guidelines:
> 1. Never approve a recipient without user confirmation.
> 2. After success, call `allowedRecipients(address)(bool)` to verify.

## Set Daily Limit

### Command Template

```bash
cast send <vault_address> "setDailyLimit(address,uint256)" <token_address> <base_units_limit> \
  --private-key $PRIVATE_KEY \
  --rpc-url https://atlantic.dplabs-internal.com
```

### Parameters

| Parameter | Type | Required | Description |
| --- | --- | --- | --- |
| `token_address` | address | Yes | `0x0000000000000000000000000000000000000000` for PHRS, ERC20 address for tokens |
| `base_units_limit` | uint256 | Yes | Daily cap in base units, e.g. `10000000000000000` for `0.01 PHRS` |

### Error Handling

| Error | Cause | Fix |
| --- | --- | --- |
| `NotOwner()` | Agent or wrong wallet tried to configure | Use owner `PRIVATE_KEY` |
| `invalid address` | Bad token or recipient address | Check address length and prefix |

> Agent Guidelines:
> 1. Convert human amounts to base units before calling.
> 2. Use small demo limits by default.
> 3. Read `dailyLimits(address)(uint256)` after success.

## Pause Or Unpause Payments

### Command Template

```bash
cast send <vault_address> "setPaused(bool)" <true_or_false> \
  --private-key $PRIVATE_KEY \
  --rpc-url https://atlantic.dplabs-internal.com
```

> Agent Guidelines:
> 1. Use pause when an agent key may be compromised.
> 2. Confirm `paused()(bool)` after success.
