'use client';

import { useState } from 'react';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../../components/ui/tabs';
import { Card, CardContent, CardHeader, CardTitle } from '../../components/ui/card';
import DepositForm from '@/app/components/DepositForm';
import WithdrawForm from '@/app/components/WithdrawForm';
import { useVaultData } from '@/app/hooks/useVaultTransactions';

export default function DashboardPage() {
  const { apy, userStaked, userBalance } = useVaultData();
  const [activeTab, setActiveTab] = useState('deposit');

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold mb-8 text-center">Pendle Fixed Yield Vault</h1>
        
        {/* Stats Overview */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">APY</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{apy}</div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Your Staked</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{userStaked} pETH</div>
            </CardContent>
          </Card>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-medium text-muted-foreground">Wallet Balance</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold">{userBalance} ETH</div>
            </CardContent>
          </Card>
        </div>

        {/* Tabs */}
        <Tabs 
          defaultValue="deposit" 
          className="w-full"
          onValueChange={(value: string) => setActiveTab(value)}
        >
          <TabsList className="grid w-full grid-cols-2">
            <TabsTrigger value="deposit">Deposit</TabsTrigger>
            <TabsTrigger value="withdraw">Withdraw</TabsTrigger>
          </TabsList>
          <TabsContent value="deposit">
            <Card className="mt-4">
              <CardContent className="p-6">
                <DepositForm />
              </CardContent>
            </Card>
          </TabsContent>
          <TabsContent value="withdraw">
            <Card className="mt-4">
              <CardContent className="p-6">
                <WithdrawForm />
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
}
