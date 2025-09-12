import { describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const address1 = accounts.get("wallet_1")!;

describe("ArtistShare tests", () => {
  it("ensures simnet is well initialized", () => {
  expect(simnet.blockHeight).toBeDefined();
});

  it("can call basic contract functions", () => {
    const { result } = simnet.callReadOnlyFn("ArtistShare", "get-artist-info", [
    `'${address1}`
], address1);
  expect(result).toBeNone();
  });
});
