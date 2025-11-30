'use client';

import { useAppKit } from '@reown/appkit/react';

export default function WalletConnector() {
  const { isConnected, address } = useAppKit();

  return (
    <div className="flex items-center gap-4">
      {isConnected ? (
        <div className="flex items-center gap-2">
          <span className="h-2 w-2 rounded-full bg-green-500"></span>
          <span className="text-sm font-medium">
            {`${address?.slice(0, 6)}...${address?.slice(-4)}`}
          </span>
        </div>
      ) : (
        <div className="flex items-center gap-2">
          <span className="h-2 w-2 rounded-full bg-red-500"></span>
          <span className="text-sm font-medium">Disconnected</span>
        </div>
      )}
      <appkit-button />
    </div>
  );
}