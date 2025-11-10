import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

const NAME = 'ApproveRouter';

const ApproveRouterModule = buildModule(NAME, (m) => {
  const approveRouter = m.contract(NAME);
  return { approveRouter };
});

export default ApproveRouterModule;
