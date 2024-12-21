# Cross-Chain Stablecoin Arbitrage Bot 🪙🚀

The **Cross-Chain Stablecoin Arbitrage Bot** is a smart contract and accompanying simulation designed to identify and act on arbitrage opportunities across two blockchain ecosystems. This innovative solution enables traders to optimize profits by leveraging price differences between stablecoins on different chains.

---

## 🌟 Features

- **Dynamic Price Updates**: Update stablecoin prices for both chains in real-time.
- **Automated Arbitrage Detection**: Analyze price differences and suggest profitable arbitrage opportunities.
- **Secure Access Control**: Only authorized entities (contract owner) can update prices, ensuring data integrity.
- **User-Friendly Design**: Simple and intuitive contract interface with robust error handling.

---

## 🔧 Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Kyautasamuel/Cross-Chain-Stablecoin-Arbitrage-Bot.git
   cd arbitrage-bot
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Run tests to verify functionality:
   ```bash
   npm test
   ```

---

## 🛠️ How It Works

### Smart Contract Design
The contract is written in Clarity and includes:
1. **Data Variables**:
   - `last-price-chain-a`: The latest stablecoin price on Chain A.
   - `last-price-chain-b`: The latest stablecoin price on Chain B.

2. **Constants**:
   - `min-price-difference`: Minimum price difference (in basis points) to trigger an arbitrage alert.
   - `contract-owner`: Only the contract owner can update prices.

3. **Public Functions**:
   - `update-prices`: Update the prices for both chains.
   - `get-arbitrage-opportunity`: Check if an arbitrage opportunity exists and, if so, identify the buy and sell chains.

### Key Scenarios
- **Profitable Arbitrage**: When the price difference between chains exceeds the `min-price-difference`, the bot identifies which chain to buy from and which to sell on.
- **No Arbitrage**: If the price difference is too small, the bot reports no opportunity.

---

## 📚 Usage

### Updating Prices
Call the `updatePrices` function to set the latest prices for Chain A and Chain B.

```typescript
updatePrices("owner-wallet", 1500, 1400);
```

- **Parameters**:
  - `txSender`: Address of the entity making the call (must match the contract owner).
  - `priceA`: The price of the stablecoin on Chain A.
  - `priceB`: The price of the stablecoin on Chain B.

---

### Detecting Arbitrage
Call the `getArbitrageOpportunity` function to check for opportunities.

```typescript
const opportunity = getArbitrageOpportunity();
```

- **Returns**:
  - `priceDifference`: The absolute difference in prices between the chains.
  - `buyOn`: The chain to buy from.
  - `sellOn`: The chain to sell on.

- **Throws**:
  - `"No arbitrage opportunity"`: If the price difference is less than `min-price-difference`.

---

## 🧪 Testing

The tests are written in **Vitest** and simulate various scenarios:

1. **Price Update by Owner**:
   - Ensures only the contract owner can update prices.
2. **Arbitrage Detection**:
   - Tests for profitable and non-profitable scenarios.
3. **Buy/Sell Chain Identification**:
   - Confirms correct chains for arbitrage actions.

Run tests with:
```bash
npm test
```

---

## 🔐 Security

- **Access Control**: Only the `contract-owner` can call the `updatePrices` function.
- **Error Handling**: Robust validation for unauthorized access and invalid state transitions.

---

## 🚀 Future Enhancements

- **Automated Execution**: Integrate with bots to automatically execute arbitrage trades.
- **Cross-Chain Communication**: Leverage interoperability solutions like Wormhole or LayerZero for seamless operations.
- **Dynamic Interest Rates**: Adjust the `min-price-difference` dynamically based on market conditions.

---

## 🤝 Contributions

Contributions are welcome! Feel free to open issues or submit pull requests for any features, bug fixes, or optimizations.

1. Fork the repo.
2. Create a new branch for your feature.
3. Submit a pull request explaining your changes.

---

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

---


Happy Arbitraging! 💰