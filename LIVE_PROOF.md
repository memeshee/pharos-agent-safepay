# Live Proof

This proof was run on Pharos Atlantic Testnet.

## Latest Prompt-Native Demo Run

- Vault: `0xA1CF605e7ceE9C81D7efA47D0dE289e0D1Ed0332`
- Vault explorer: `https://atlantic.pharosscan.xyz/address/0xA1CF605e7ceE9C81D7efA47D0dE289e0D1Ed0332`
- Deposit amount: `0.0001 PHRS`
- Payment amount: `0.00001 PHRS`
- Payment tx: `0x022b6941ab4466f49f4c31fadcc4ec5a65e6775f789483bf474993ecfee0bbaf`
- Payment explorer: `https://atlantic.pharosscan.xyz/tx/0x022b6941ab4466f49f4c31fadcc4ec5a65e6775f789483bf474993ecfee0bbaf`
- Payment id: `0xc3a399990b9636867c7da7928bffc16d0f7210e9d6597d187f05c9faf4302b67`

Verified behavior:

- Displayed builder natural-language prompts.
- Displayed SafePay Agent responses.
- Hid raw command spam by default.
- Does not print pause-marker text.
- Proved the same live flow: validate, test, connect, deploy, configure, fund, pay, receipt, duplicate payment blocked.

## Wallet Check

- Derived address: `0x4Ba1e9e275EF61B56C99532D0066506436201D73`
- Chain ID: `688689`
- Native balance before final run: about `9.998672693998762694 PHRS`
- Registry USDC balance: `0`
- Registry USDT balance: `0`

The wallet had native PHRS, so live verification used tiny PHRS amounts.

## Previous Command-Verbose Run

- Vault: `0x457ae4d9e8CC1bC6bf3babA9133D1fCe283a9ABE`
- Vault explorer: `https://atlantic.pharosscan.xyz/address/0x457ae4d9e8CC1bC6bf3babA9133D1fCe283a9ABE`
- Deposit amount: `0.0001 PHRS`
- Payment amount: `0.00001 PHRS`
- Payment tx: `0x58009ad72214dd7b6b63407ebb557d92e5e76923caa68421edd3a613d0860ecf`
- Payment explorer: `https://atlantic.pharosscan.xyz/tx/0x58009ad72214dd7b6b63407ebb557d92e5e76923caa68421edd3a613d0860ecf`
- Payment id: `0xaf47edda9ecfaa1f3b42f09e469c84304f261ff66d7c1f6d7c26784173f27829`

## Verified Behavior

- Skill validator passed.
- Foundry tests passed.
- Pharos Atlantic chain id returned `688689`.
- SafePay vault deployed successfully.
- Recipient was allowlisted.
- Native PHRS daily limit was set to `0.0001 PHRS`.
- Vault was funded with `0.0001 PHRS`.
- Agent executed `0.00001 PHRS` payment.
- `PaymentExecuted` receipt was returned by `cast logs`.
- Reusing the same `paymentId` reverted with `DuplicatePayment`.
