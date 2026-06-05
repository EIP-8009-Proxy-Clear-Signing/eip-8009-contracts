import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

const CoreModule = buildModule('Core', (m) => {
  const balanceProxy = m.contract('BalanceProxy');
  const approveRouter = m.contract('ApproveRouter');
  const permitRouter = m.contract('PermitRouter');
  const safeRouter = m.contract('SafeRouter');

  return { balanceProxy, approveRouter, permitRouter, safeRouter };
});

export default CoreModule;
