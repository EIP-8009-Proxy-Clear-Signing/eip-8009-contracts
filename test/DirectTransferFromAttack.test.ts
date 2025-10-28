import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers';
import { expect } from 'chai';
import { viem, ignition } from 'hardhat';
import { parseEther, encodeFunctionData } from 'viem';

import BalanceProxyModule from '@/ignition/modules/balance-proxy';

describe('�️ SECURITY: Direct transferFrom Attack Protection', function () {
  async function deployFixture() {
    const [owner, attacker, victim] = await viem.getWalletClients();

    const { balanceProxy } = await ignition.deploy(BalanceProxyModule, {
      defaultSender: owner.account.address,
    });

    const erc20 = await viem.deployContract('ERC20Mock', ['STEAL', 'STEAL'], {
      client: { wallet: owner },
    });

    return { owner, attacker, victim, balanceProxy, erc20 };
  }

  it('�️ Should reject direct transferFrom and protect user tokens', async function () {
    const { owner, attacker, victim, balanceProxy, erc20 } =
      await loadFixture(deployFixture);

    const VICTIM_AMOUNT = parseEther('1000');

    console.log('\n📋 SETUP:');

    await erc20.write.mint([victim.account.address, VICTIM_AMOUNT]);
    console.log(`  ✅ Victim has ${VICTIM_AMOUNT} tokens`);

    await erc20.write.approve([balanceProxy.address, VICTIM_AMOUNT], {
      account: victim.account,
    });
    console.log(`  ✅ Victim approved proxy to spend ${VICTIM_AMOUNT} tokens`);

    const victimBalanceBefore = await erc20.read.balanceOf([
      victim.account.address,
    ]);
    const attackerBalanceBefore = await erc20.read.balanceOf([
      attacker.account.address,
    ]);

    console.log('\n📊 BEFORE ATTACK:');
    console.log(`  Victim balance: ${victimBalanceBefore}`);
    console.log(`  Attacker balance: ${attackerBalanceBefore}`);

    expect(victimBalanceBefore).to.equal(VICTIM_AMOUNT);
    expect(attackerBalanceBefore).to.equal(0n);

    console.log('\n🚨 ATTACK: Direct transferFrom via proxyCall');

    const transferFromCalldata = encodeFunctionData({
      abi: [
        {
          name: 'transferFrom',
          type: 'function',
          inputs: [
            { name: 'from', type: 'address' },
            { name: 'to', type: 'address' },
            { name: 'amount', type: 'uint256' },
          ],
          outputs: [{ name: '', type: 'bool' }],
        },
      ],
      functionName: 'transferFrom',
      args: [victim.account.address, attacker.account.address, VICTIM_AMOUNT],
    });

    await balanceProxy.write.proxyCall(
      [[], [], erc20.address, transferFromCalldata, []],
      {
        account: attacker.account,
      },
    );

    console.log(`  ✅ Attack call completed`);

    // Check final state
    const victimBalanceAfter = await erc20.read.balanceOf([
      victim.account.address,
    ]);
    const attackerBalanceAfter = await erc20.read.balanceOf([
      attacker.account.address,
    ]);

    console.log('\n💀 RESULT:');
    console.log(`  Victim balance: ${victimBalanceAfter}`);
    console.log(`  Attacker balance: ${attackerBalanceAfter}`);

    // ТЕСТ БЕЗПЕКИ: Атака повинна ПРОВАЛИТИСЬ!
    expect(victimBalanceAfter).to.equal(VICTIM_AMOUNT); // Victim should keep all tokens
    expect(attackerBalanceAfter).to.equal(0n); // Attacker should get nothing

    console.log('\n🛡️ ATTACK BLOCKED - CONTRACT IS SECURE!');
    console.log('✅ Direct transferFrom was rejected');
  });
});
