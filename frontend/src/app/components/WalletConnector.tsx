'use client';

export default function WalletConnector() {
  return <appkit-button />;
}

export default function WalletConnector() {
  const { address, isConnected } = useAccount();
  const { disconnect } = useDisconnect();
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();

  const handleCopyAddress = () => {
    if (address) {
      navigator.clipboard.writeText(address);
      message.success('Address copied to clipboard!');
    }
  };

  const handleNetworkChange = async (newChainId: number) => {
    try {
      await switchChain({ chainId: newChainId });
      message.success('Network switched successfully');
    } catch (error) {
      message.error('Failed to switch network');
    }
  };

  if (!isConnected) {
    return (
      <Button type="primary" onClick={() => {}}>
        Connect Wallet
      </Button>
    );
  }

  const items = [
    {
      key: '1',
      label: (
        <div className="flex items-center gap-2 p-2">
          <CopyOutlined />
          <span>Copy Address</span>
        </div>
      ),
      onClick: handleCopyAddress,
    },
    {
      key: '2',
      label: (
        <div className="flex items-center gap-2 p-2">
          <DisconnectOutlined />
          <span>Disconnect</span>
        </div>
      ),
      onClick: () => disconnect(),
    },
  ];

  const networkItems = [
    {
      key: '1',
      label: 'Ethereum Mainnet',
      onClick: () => handleNetworkChange(1),
    },
    {
      key: '2',
      label: 'Sepolia Testnet',
      onClick: () => handleNetworkChange(11155111),
    },
  ];

  return (
    <div className="flex items-center gap-4">
      <Dropdown
        menu={{ items }}
        trigger={['click']}
        placement="bottomRight"
      >
        <Button type="primary" className="bg-blue-500">
          {`${address?.slice(0, 6)}...${address?.slice(-4)}`}
        </Button>
      </Dropdown>
      
      <Dropdown
        menu={{ items: networkItems }}
        placement="bottomRight"
      >
        <Button>
          {chainId === 1 ? 'Ethereum' : chainId === 11155111 ? 'Sepolia' : 'Unknown Network'}
        </Button>
      </Dropdown>
    </div>
  );
}
