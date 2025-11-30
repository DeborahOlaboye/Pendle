'use client';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { createAppKit } from '@reown/appkit/react';
import { WagmiAdapter } from '@reown/appkit-adapter-wagmi';
import { mainnet, sepolia } from '@reown/appkit/networks';
import { cookieToInitialState, WagmiProvider, createStorage, cookieStorage } from 'wagmi';

const queryClient = new QueryClient();

const projectId = process.env.NEXT_PUBLIC_PROJECT_ID;

if (!projectId) {
  throw new Error('Project ID is not defined');
}

const wagmiAdapter = new WagmiAdapter({
  storage: createStorage({
    storage: cookieStorage
  }),
  ssr: true,
  projectId,
  networks: [mainnet, sepolia]
});

createAppKit({
  adapters: [wagmiAdapter],
  projectId,
  networks: [mainnet, sepolia],
  defaultNetwork: mainnet,
  metadata: {
    name: 'Pendle',
    description: 'Pendle Finance',
    url: 'http://localhost:3000',
    icons: ['https://avatars.githubusercontent.com/u/179229932']
  },
  features: {
    analytics: true
  }
});

export function Providers({ 
  children,
  cookies 
}: { 
  children: React.ReactNode;
  cookies: string | null;
}) {
  const initialState = cookieToInitialState(wagmiAdapter.wagmiConfig, cookies);

  return (
    <WagmiProvider config={wagmiAdapter.wagmiConfig} initialState={initialState}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </WagmiProvider>
  );
}
