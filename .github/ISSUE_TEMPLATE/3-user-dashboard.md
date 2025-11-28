# User Dashboard

**Priority**: High  
**Estimated Time**: 2 days  
**Labels**: frontend, dashboard, user-interface

## Description
Create a comprehensive dashboard showing user's positions, yield earnings, and performance metrics.

## Tasks
- [ ] Design and implement dashboard layout
- [ ] Display user's total value locked (TVL)
- [ ] Show current APY and estimated yields
- [ ] List active positions with details
- [ ] Add historical performance chart
- [ ] Include transaction history
- [ ] Add portfolio allocation visualization

## Acceptance Criteria
- Clean, intuitive dashboard layout
- Real-time data updates
- Responsive design
- Clear visualization of earnings
- Easy navigation between positions

## Technical Notes
- Use `recharts` for data visualization
- Implement data fetching with `react-query`
- Add loading states and error boundaries
- Optimize for performance with memoization

## Files to Create/Modify
- `src/app/dashboard/page.tsx`
- `src/app/components/PortfolioChart.tsx`
- `src/app/components/PositionList.tsx`
- `src/app/hooks/usePortfolioData.ts`
