'use client';

import { ReownProvider } from '@reown/next';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { mainnet, sepolia } from 'viem/chains';

const queryClient = new QueryClient();

const config = {
  appName: 'Pendle',
  chains: [mainnet, sepolia],
  projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID, // You'll need to set this in your .env file
};

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ReownProvider config={config}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </ReownProvider>
  );
}
