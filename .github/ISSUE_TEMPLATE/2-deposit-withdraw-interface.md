# Deposit/Withdraw Interface

**Priority**: High  
**Estimated Time**: 2 days  
**Labels**: frontend, features, transactions

## Description
Create the main interface for users to deposit and withdraw funds from the Pendle Fixed Yield Vault.

## Tasks
- [ ] Create deposit form component
- [ ] Implement withdraw form component
- [ ] Add token selection (ETH/stETH)
- [ ] Display exchange rates and APY
- [ ] Add transaction approval flow
- [ ] Implement transaction status indicators
- [ ] Add success/error notifications

## Acceptance Criteria
- Users can deposit ETH/stETH
- Users can withdraw their funds
- Clear display of transaction details
- Proper handling of transaction states
- Responsive design for all screen sizes

## Technical Notes
- Use `react-hook-form` for form handling
- Integrate with wagmi for transaction handling
- Add loading states and skeleton loaders
- Include transaction confirmation dialogs

## Files to Create/Modify
- `src/app/components/DepositForm.tsx`
- `src/app/components/WithdrawForm.tsx`
- `src/app/hooks/useVaultTransactions.ts`
- Update main dashboard page
