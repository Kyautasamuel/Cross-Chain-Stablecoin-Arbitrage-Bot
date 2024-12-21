import { describe, it, expect, beforeEach } from "vitest";

// Mocking the blockchain state and contract functions
type ArbitrageState = {
  lastPriceChainA: number;
  lastPriceChainB: number;
};

let arbitrageState: ArbitrageState;

// Constants
const contractOwner = "owner-wallet"; // Mock contract owner
const minPriceDifference = 100; // Minimum price difference in basis points (1%)

// Helper function to reset the Arbitrage state
const resetArbitrageState = () => {
  arbitrageState = {
    lastPriceChainA: 0,
    lastPriceChainB: 0,
  };
};

// Contract functions to test
const updatePrices = (txSender: string, priceA: number, priceB: number) => {
  if (txSender !== contractOwner) {
    throw new Error("Unauthorized");
  }
  arbitrageState.lastPriceChainA = priceA;
  arbitrageState.lastPriceChainB = priceB;
  return true;
};

const getArbitrageOpportunity = () => {
  const { lastPriceChainA, lastPriceChainB } = arbitrageState;
  const difference = Math.abs(lastPriceChainA - lastPriceChainB);

  if (difference >= minPriceDifference) {
    return {
      priceDifference: difference,
      buyOn: lastPriceChainB > lastPriceChainA ? "chain-a" : "chain-b",
      sellOn: lastPriceChainB > lastPriceChainA ? "chain-b" : "chain-a",
    };
  } else {
    throw new Error("No arbitrage opportunity");
  }
};

// Tests using Vitest
describe("Cross-Chain Stablecoin Arbitrage Bot", () => {
  beforeEach(() => {
    // Reset the arbitrage state before each test
    resetArbitrageState();
  });

  it("should update prices when called by the contract owner", () => {
    const success = updatePrices(contractOwner, 1500, 1400);
    expect(success).toBe(true);
    expect(arbitrageState.lastPriceChainA).toBe(1500);
    expect(arbitrageState.lastPriceChainB).toBe(1400);
  });

  it("should throw an error if a non-owner tries to update prices", () => {
    expect(() => updatePrices("non-owner-wallet", 1500, 1400)).toThrow("Unauthorized");
  });

  it("should detect an arbitrage opportunity when price difference exceeds minimum", () => {
    arbitrageState.lastPriceChainA = 2000;
    arbitrageState.lastPriceChainB = 1800;

    const opportunity = getArbitrageOpportunity();
    expect(opportunity.priceDifference).toBe(200);
    expect(opportunity.buyOn).toBe("chain-b");
    expect(opportunity.sellOn).toBe("chain-a");
  });

  it("should not detect an arbitrage opportunity for a small price difference", () => {
    arbitrageState.lastPriceChainA = 1500;
    arbitrageState.lastPriceChainB = 1490;

    expect(() => getArbitrageOpportunity()).toThrow("No arbitrage opportunity");
  });

  it("should correctly identify the chains to buy and sell for arbitrage", () => {
    arbitrageState.lastPriceChainA = 1200;
    arbitrageState.lastPriceChainB = 1400;

    const opportunity = getArbitrageOpportunity();
    expect(opportunity.buyOn).toBe("chain-a");
    expect(opportunity.sellOn).toBe("chain-b");
  });

  it("should handle multiple updates and detect arbitrage opportunities correctly", () => {
    updatePrices(contractOwner, 1500, 1300);
    const firstOpportunity = getArbitrageOpportunity();

    expect(firstOpportunity.priceDifference).toBe(200);
    expect(firstOpportunity.buyOn).toBe("chain-b");
    expect(firstOpportunity.sellOn).toBe("chain-a");

    updatePrices(contractOwner, 1100, 1250);
    const secondOpportunity = getArbitrageOpportunity();

    expect(secondOpportunity.priceDifference).toBe(150);
    expect(secondOpportunity.buyOn).toBe("chain-a");
    expect(secondOpportunity.sellOn).toBe("chain-b");
  });
});
