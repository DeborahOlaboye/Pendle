'use client';

import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { useAppKit } from '@reown/appkit/react';
import { parseEther } from 'viem';
import { mainnet } from '@reown/appkit/networks';

const TOKENS = [
  { id: 'eth', name: 'ETH' },
  { id: 'steth', name: 'stETH' },
];

type FormData = {
  amount: string;
  token: string;
};

export default function DepositForm() {
  const { register, handleSubmit, formState: { errors }, watch } = useForm<FormData>({
    defaultValues: {
      token: 'eth',
      amount: '',
    },
  });

  const [isApproving, setIsApproving] = useState(false);
  const [isDepositing, setIsDepositing] = useState(false);
  const { isConnected, address } = useAppKit();
  const selectedToken = watch('token');

  const { executeTransaction } = useVaultTransactions();
  const [isDepositProcessing, setIsDepositProcessing] = useState(false);

  const onSubmit = async (data: FormData) => {
    if (!isConnected) return;
    
    try {
      setIsDepositing(true);
      const amount = parseEther(data.amount);
      
      // In a real implementation, you would use the Reown AppKit to interact with contracts
      // This is a placeholder for the actual contract interaction
      const result = await executeTransaction(async () => {
        // Replace with actual contract interaction
        console.log(`Depositing ${data.amount} ${selectedToken.toUpperCase()}`);
        // Simulate API call
        await new Promise(resolve => setTimeout(resolve, 2000));
        return { success: true };
      });
      
      if (result.success) {
        // Handle successful deposit
        console.log('Deposit successful');
      }
    } catch (error) {
      console.error('Deposit error:', error);
    } finally {
      setIsDepositing(false);
      setIsApproving(false);
    }
  };

  // Mock APY - replace with actual data
  const currentAPY = '5.25%';

  return (
    <div className="w-full max-w-md p-6 bg-white rounded-lg shadow-md">
      <h2 className="text-2xl font-bold mb-6 text-gray-800">Deposit</h2>
      
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Select Token
          </label>
          <div className="flex space-x-2 mb-4">
            {TOKENS.map((token) => (
              <label key={token.id} className="inline-flex items-center">
                <input
                  type="radio"
                  value={token.id}
                  {...register('token')}
                  className="h-4 w-4 text-blue-600"
                />
                <span className="ml-2 text-gray-700">{token.name}</span>
              </label>
            ))}
          </div>
        </div>

        <div>
          <label htmlFor="amount" className="block text-sm font-medium text-gray-700 mb-1">
            Amount
          </label>
          <div className="relative rounded-md shadow-sm">
            <input
              id="amount"
              type="number"
              step="0.000000000000000001"
              min="0"
              placeholder="0.0"
              className="w-full p-3 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
              {...register('amount', {
                required: 'Amount is required',
                min: { value: 0.0001, message: 'Amount must be greater than 0' },
              })}
            />
            <div className="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
              <span className="text-gray-500 sm:text-sm">{selectedToken.toUpperCase()}</span>
            </div>
          </div>
          {errors.amount && (
            <p className="mt-1 text-sm text-red-600">{errors.amount.message}</p>
          )}
        </div>

        <div className="bg-gray-50 p-3 rounded-md">
          <div className="flex justify-between text-sm text-gray-600">
            <span>APY</span>
            <span className="font-medium">{currentAPY}</span>
          </div>
          <div className="flex justify-between text-sm text-gray-600 mt-1">
            <span>Exchange Rate</span>
            <span className="font-medium">1 {selectedToken.toUpperCase()} = 1 p{selectedToken.toUpperCase()}</span>
          </div>
        </div>

        <button
          type="submit"
          disabled={isApproving || isDepositing || !isConnected}
          className={`w-full py-3 px-4 rounded-md text-white font-medium ${
            isApproving || isDepositing || !isConnected
              ? 'bg-gray-400 cursor-not-allowed'
              : 'bg-blue-600 hover:bg-blue-700'
          }`}
        >
          {!isConnected
            ? 'Connect Wallet'
            : isApproving
            ? 'Approving...'
            : isDepositing || isDepositProcessing
            ? 'Processing...'
            : 'Deposit'}
        </button>
      </form>
    </div>
  );
}
