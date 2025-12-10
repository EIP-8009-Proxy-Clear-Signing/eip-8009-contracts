import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

const NAME = 'PermitRouter';

const PermitRouterModule = buildModule(NAME, (m) => {
  const permitRouter = m.contract(NAME);
  return { permitRouter };
});

export default PermitRouterModule;
