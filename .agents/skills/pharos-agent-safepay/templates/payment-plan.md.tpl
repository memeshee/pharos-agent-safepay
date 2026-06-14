# SafePay Payment Plan

- Vault: `<vault_address>`
- Token: `<token_address_or_PHRS>`
- Recipient: `<recipient_address>`
- Amount: `<human_amount>`
- Payment ID: `<payment_id>`
- Memo hash: `<memo_hash>`

## Preflight

```bash
cast call <vault_address> "allowedRecipients(address)(bool)" <recipient_address> --rpc-url $RPC
cast call <vault_address> "remainingToday(address)(uint256)" <token_address> --rpc-url $RPC
cast call <vault_address> "usedPaymentIds(bytes32)(bool)" <payment_id> --rpc-url $RPC
```

## Execute

```bash
cast send <vault_address> "<payment_function>" <args> \
  --private-key $AGENT_PRIVATE_KEY \
  --rpc-url $RPC
```
