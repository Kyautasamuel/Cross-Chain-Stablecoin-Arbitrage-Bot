import { describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const deployer = accounts.get("wallet_1")!;

describe("arbitrage-bot", () => {
    it("should allow owner to update prices", () => {
        const { result } = simnet.callPublicFn("arbitrage-bot", "update-prices", [
            types.uint(1000000), // $1.00 on chain A
            types.uint(1020000)  // $1.02 on chain B
        ], deployer);
        expect(result).toBeOk(types.bool(true));
    });

    it("should detect arbitrage opportunity", () => {
        const { result } = simnet.callReadOnlyFn(
            "arbitrage-bot",
            "get-arbitrage-opportunity",
            [],
            deployer
        );
        expect(result).toBeOk();
    });
});
