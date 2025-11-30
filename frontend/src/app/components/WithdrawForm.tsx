'use client';

import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { useAppKit } from '@reown/appkit/react';
import { parseEther } from 'viem';
import { useContractWrite, useWaitForTransaction } from 'wagmi';

type FormData = {
  amount: string;
};

export default function WithdrawForm() {
  const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
    defaultValues: {
      amount: '',
    },
  });

  const [isWithdrawing, setIsWithdrawing] = useState(false);
  const { isConnected } = useAppKit();

  // Mock contract interaction - replace with actual contract ABI and address
  const { write: withdraw, data: withdrawData } = useContractWrite({
    address: '0x...', // Replace with actual contract address
    abi: [
      'function withdraw(uint256 amount) external',
    ],
    functionName: 'withdraw',
  });

  const { isLoading: isWithdrawProcessing } = useWaitForTransaction({
    hash: withdrawData?.hash,
    onSuccess: () => {
      setIsWithdrawing(false);
      // Show success notification
    },
    onError: () => {
      setIsWithdrawing(false);
      // Show error notification
    },
  });

  const onSubmit = async (data: FormData) => {
    if (!isConnected) return;
    
    try {
      setIsWithdrawing(true);
      const amount = parseEther(data.amount);
      
      withdraw({
        args: [amount],
      });
    } catch (error) {
      console.error('Withdraw error:', error);
      setIsWithdrawing(false);
    }
  };

  // Mock user balance - replace with actual data
  const userBalance = '10.5';

  return (
    <div className="w-full max-w-md p-6 bg-white rounded-lg shadow-md">
      <h2 className="text-2xl font-bold mb-6 text-gray-800">Withdraw</h2>
      
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
        <div>
          <div className="flex justify-between items-center mb-1">
            <label htmlFor="amount" className="block text-sm font-medium text-gray-700">
              Amount
            </label>
            <button
              type="button"
              onClick={() => {
                // Set max amount
                const amountInput = document.getElementById('amount') as HTMLInputElement;
                if (amountInput) {
                  amountInput.value = userBalance;
                }
              }}
              className="text-xs text-blue-600 hover:text-blue-800"
            >
              Max: {userBalance} pETH
            </button>
          </div>
          <div className="relative rounded-md shadow-sm">
            <input
              id="amount"
              type="number"
              step="0.000000000000000001"
              min="0"
              max={userBalance}
              placeholder="0.0"
              className="w-full p-3 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
              {...register('amount', {
                required: 'Amount is required',
                min: { value: 0.0001, message: 'Amount must be greater than 0' },
                max: { value: Number(userBalance), message: 'Insufficient balance' },
              })}
            />
            <div className="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
              <span className="text-gray-500 sm:text-sm">pETH</span>
            </div>
          </div>
          {errors.amount && (
            <p className="mt-1 text-sm text-red-600">{errors.amount.message}</p>
          )}
        </div>

        <div className="bg-gray-50 p-3 rounded-md">
          <div className="flex justify-between text-sm text-gray-600">
            <span>You will receive</span>
            <span className="font-medium">0.0 ETH</span>
          </div>
        </div>

        <button
          type="submit"
          disabled={isWithdrawing || !isConnected}
          className={`w-full py-3 px-4 rounded-md text-white font-medium ${
            isWithdrawing || !isConnected
              ? 'bg-gray-400 cursor-not-allowed'
              : 'bg-blue-600 hover:bg-blue-700'
          }`}
        >
          {!isConnected
            ? 'Connect Wallet'
            : isWithdrawing || isWithdrawProcessing
            ? 'Processing...'
            : 'Withdraw'}
        </button>
      </form>
    </div>
  );
}
