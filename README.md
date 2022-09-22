# OVRVestingV2 Smart Contract

To grant tokens to specified address call (ONLY ADMIN):

```js
granting(
    address _beneficiary, // beneficiary address
    uint256 _amount, // the amount of tokens to be granted
    uint256 _start, // unix start date
    uint256 _end, // unix end date
    bool _revocable // whether the grant is revocable or not
)
```
Use https://www.unixtimestamp.com/ for dates.

It is possible to revoke (ONLY ADMIN) and withdraw the difference between the total amount and the funds already withdrawn by the beneficiary calling:

```js
revoke(
    address _account, // beneficiary address
)
```

### 🎯 Setup

Create `.env` file with this configuration:

```
ETHERSCAN_API_KEY=""
PRIVATE_KEY=""
COINMARKETCAP_API_KEY=""
ALCHEMY_KEY=""
```

Run `nvm use` to choose npm version `16.17.0`.
```
nvm use
npm install
```

--- 

### 🗞️ Tests

```
npx hardhat test
```

---

### ⤴️ Deployment
Remember to check constructor specified `scripts/deploy.js`.

```
npx hardhat run scripts/deploy.js --network mainnet
```

### Verify Smart Contract on Etherscan

```
npx hardhat verify --network mainnet DEPLOYED_CONTRACT_ADDRESS
```

---
