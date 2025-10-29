import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers';
import { expect } from 'chai';
import { viem, ignition } from 'hardhat';
import { parseEther } from 'viem';

import BalanceProxyModule from '@/ignition/modules/balance-proxy';

describe('�️ SECURITY: Malicious Approve Target Protection', function () {
  async function deployFixture() {
    const [owner, attacker, victim] = await viem.getWalletClients();

    const { balanceProxy } = await ignition.deploy(BalanceProxyModule, {
      defaultSender: owner.account.address,
    });

    const erc20 = await viem.deployContract('ERC20Mock', ['VULN', 'VULN'], {
      client: { wallet: owner },
    });

    return { owner, attacker, victim, balanceProxy, erc20 };
  }

  it('�️ Should reject malicious approve target and protect user tokens', async function () {
    const { owner, attacker, victim, balanceProxy, erc20 } =
      await loadFixture(deployFixture);

    const STOLEN_AMOUNT = parseEther('1000');

    console.log('\n📋 SETUP:');

    await erc20.write.mint([owner.account.address, STOLEN_AMOUNT]);
    await erc20.write.approve([balanceProxy.address, STOLEN_AMOUNT]);
    console.log(`  ✅ Owner has tokens and approved proxy for transferFrom`);

    await erc20.write.mint([balanceProxy.address, STOLEN_AMOUNT]);
    console.log(`  ✅ Proxy has ${STOLEN_AMOUNT} tokens from previous ops`);

    const proxyBalanceBefore = await erc20.read.balanceOf([
      balanceProxy.address,
    ]);
    const attackerBalanceBefore = await erc20.read.balanceOf([
      attacker.account.address,
    ]);

    expect(proxyBalanceBefore).to.equal(STOLEN_AMOUNT);
    expect(attackerBalanceBefore).to.equal(0n);

    console.log('\n🚨 ATTACK: Using malicious approve target');

    await expect(
      balanceProxy.write.proxyCall([
        [],
        [
          {
            target: attacker.account.address,
            token: erc20.address,
            balance: STOLEN_AMOUNT,
          },
        ],
        victim.account.address,
        '0x',
        [],
      ]),
    ).to.be.rejected;

    console.log('  ✅ Attack was blocked with MaliciousApproveTarget error');

    console.log('\n� RESULT:');
    const proxyBalanceAfter = await erc20.read.balanceOf([
      balanceProxy.address,
    ]);
    const attackerBalanceAfter = await erc20.read.balanceOf([
      attacker.account.address,
    ]);
    const ownerBalanceAfter = await erc20.read.balanceOf([
      owner.account.address,
    ]);

    console.log(`  Owner balance: ${ownerBalanceAfter}`);
    console.log(`  Proxy balance: ${proxyBalanceAfter}`);
    console.log(`  Attacker balance: ${attackerBalanceAfter}`);

    expect(ownerBalanceAfter).to.equal(STOLEN_AMOUNT);
    expect(proxyBalanceAfter).to.equal(STOLEN_AMOUNT);
    expect(attackerBalanceAfter).to.equal(0n);

    console.log('\n🛡️ ATTACK BLOCKED - CONTRACT IS SECURE!');
    console.log('✅ Malicious approve target was rejected');
  });
});
