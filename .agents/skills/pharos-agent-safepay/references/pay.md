# Payment Instructions

Use this file when depositing funds, executing payments, or checking remaining budget.

## Deposit Native PHRS

### Command Template

```bash
cast send <vault_address> "depositNative()" \
  --value <amount>ether \
  --private-key $PRIVATE_KEY \
  --rpc-url https://atlantic.dplabs-internal.com
```

> Agent Guidelines:
> 1. Use tiny demo deposits such as `0.001ether`.
> 2. Confirm vault balance with `cast balance <vault_address> --rpc-url <rpc> --ether`.

## Execute Native Payment

### Command Template

```bash
PAYMENT_ID=$(cast keccak "invoice-001")
MEMO_HASH=$(cast keccak "demo payment memo")

cast send <vault_address> "payNative(address,uint256,bytes32,bytes32)" \
  <recipient_address> <amount_wei> $PAYMENT_ID $MEMO_HASH \
  --private-key $AGENT_PRIVATE_KEY \
  --rpc-url https://atlantic.dplabs-internal.com
```

### Preflight Calls

```bash
cast call <vault_address> "allowedRecipients(address)(bool)" <recipient_address> --rpc-url $RPC
cast call <vault_address> "remainingToday(address)(uint256)" 0x0000000000000000000000000000000000000000 --rpc-url $RPC
cast call <vault_address> "usedPaymentIds(bytes32)(bool)" $PAYMENT_ID --rpc-url $RPC
```

### Error Handling

| Error | Cause | Fix |
| --- | --- | --- |
| `RecipientNotAllowed` | Recipient not approved | Owner must call `setRecipientAllowed` |
| `DailyLimitExceeded` | Payment exceeds remaining budget | Lower amount or owner raises limit |
| `DuplicatePayment` | Reused payment id | Use a new id or inspect existing receipt |
| `Paused` | Vault is paused | Owner must unpause after reviewing risk |
| `NotAgentOrOwner` | Wrong signer | Use `AGENT_PRIVATE_KEY` or owner key |

> Agent Guidelines:
> 1. Always run all preflight calls before payment.
> 2. Never auto-generate a second payment after a revert without checking `usedPaymentIds`.
> 3. After success, show tx link and query `PaymentExecuted` from the deployment or payment block.

## Execute ERC20 Payment

### Command Template

```bash
PAYMENT_ID=$(cast keccak "invoice-erc20-001")
MEMO_HASH=$(cast keccak "erc20 demo payment memo")

cast send <vault_address> "payERC20(address,address,uint256,bytes32,bytes32)" \
  <token_address> <recipient_address> <amount_base_units> $PAYMENT_ID $MEMO_HASH \
  --private-key $AGENT_PRIVATE_KEY \
  --rpc-url https://atlantic.dplabs-internal.com
```

> Agent Guidelines:
> 1. Use `assets/tokens.json` for known token decimals.
> 2. Confirm the vault token balance with `balanceOf(address)`.
> 3. Confirm `remainingToday(token)` covers the payment.

## Check Remaining Budget

### Command Template

```bash
cast call <vault_address> "remainingToday(address)(uint256)" <token_address> \
  --rpc-url https://atlantic.dplabs-internal.com
```

### Output Parsing

Convert the returned base-unit integer to human units using the token decimals.
