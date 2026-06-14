# Receipt Instructions

Use this file when the user wants an audit trail for agent payments.

## Query PaymentExecuted Logs

### Command Template

```bash
cast logs \
  --rpc-url https://atlantic.dplabs-internal.com \
  --address <vault_address> \
  --from-block <from_block> \
  --to-block latest \
  "PaymentExecuted(bytes32,address,address,address,uint256,uint256,uint256,bytes32)"
```

### Output Parsing

| Event Field | Description |
| --- | --- |
| `paymentId` | Unique idempotency key for the payment |
| `token` | Zero address for PHRS, ERC20 address for token payment |
| `recipient` | Paid recipient |
| `operator` | Agent or owner address that executed the payment |
| `amount` | Paid amount in base units |
| `day` | UTC day bucket from `block.timestamp / 1 days` |
| `spentAfter` | Total spent for that token in the day after payment |
| `memoHash` | Hash of invoice, task id, or off-chain memo |

### Error Handling

| Error | Cause | Fix |
| --- | --- | --- |
| Empty result | No matching payments | Lower `from_block` or confirm vault address |
| Block range too large | RPC log range limit | Query smaller ranges |
| Invalid address | Bad vault address | Validate `0x` + 40 hex chars |

> Agent Guidelines:
> 1. Always use deployment block, payment block, or a recent block for `from_block`; Pharos Atlantic rejects overly broad log ranges.
> 2. Convert token amounts to human units.
> 3. Show explorer transaction links when transaction hashes are present.
> 4. Treat logs as the source of truth for payment receipts.
