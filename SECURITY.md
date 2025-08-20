# Security Policy

Security vulnerabilities should be disclosed by email to contact@redduck.io.

## Security Patches

Security vulnerabilities will be patched as soon as responsibly possible, and published as an advisory on this repository (see [advisories]) and on the affected npm packages.

[advisories]: https://github.com/RedDuck-Software/eip-xxxx-contracts/security/advisories

Projects that build on OpenZeppelin Contracts are encouraged to clearly state, in their source code and websites, how to be contacted about security issues in the event that a direct notification is considered necessary. We recommend including it in the NatSpec for the contract as `/// @custom:security-contact security@example.com`.

Additionally, we recommend installing the library through npm and setting up vulnerability alerts such as [Dependabot].

[Dependabot]: https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/about-supply-chain-security#what-is-dependabot

Note as well that the Solidity language itself only guarantees security updates for the latest release.