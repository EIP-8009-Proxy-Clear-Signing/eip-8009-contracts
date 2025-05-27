import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

const NAME = 'BalanceProxy';

const BalanceProxyModule = buildModule(NAME, (m) => {
  const balanceProxy = m.contract(NAME);

  return { balanceProxy };
});

export default BalanceProxyModule;
