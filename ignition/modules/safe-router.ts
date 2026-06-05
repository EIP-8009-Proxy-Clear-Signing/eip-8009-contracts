import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

const SafeRouterModule = buildModule('SafeRouter', (m) => {
  const safeRouter = m.contract('SafeRouter');
  return { safeRouter };
});

export default SafeRouterModule;
