import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { ERC20F } from "../typechain-types";
import { Contract } from "ethers";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";

describe("ERC20F", function () {
  let token: ERC20F;
  let owner: SignerWithAddress;
  let admin: SignerWithAddress;
  let minter: SignerWithAddress;
  let pauser: SignerWithAddress;
  let user: SignerWithAddress;

  beforeEach(async function () {
    console.log("\n=== Deploying fresh contract ===");
    [owner, admin, minter, pauser, user] = await ethers.getSigners();
    console.log("Admin address:", admin.address);
    console.log("Minter address:", minter.address);
    console.log("Pauser address:", pauser.address);

    const ERC20F = await ethers.getContractFactory("ERC20F");
    token = (await upgrades.deployProxy(
      ERC20F,
      [
        "Test Token",
        "TEST",
        admin.address,
        minter.address,
        pauser.address,
      ],
      { initializer: "initialize" }
    )) as unknown as ERC20F;
    await token.waitForDeployment();
    console.log("Token deployed to:", await token.getAddress());
  });

  describe("Initialization", function () {
    it("Should set the correct name and symbol", async function () {
      console.log("\n=== Testing name and symbol ===");
      const name = await token.name();
      const symbol = await token.symbol();
      console.log("Expected name: Test Token");
      console.log("Actual name:", name);
      console.log("Expected symbol: TEST");
      console.log("Actual symbol:", symbol);
      expect(name).to.equal("Test Token");
      expect(symbol).to.equal("TEST");
    });

    it("Should assign roles correctly", async function () {
      console.log("\n=== Testing role assignments ===");
      const DEFAULT_ADMIN_ROLE = await token.DEFAULT_ADMIN_ROLE();
      const MINTER_ROLE = await token.MINTER_ROLE();
      const PAUSER_ROLE = await token.PAUSER_ROLE();

      const adminHasRole = await token.hasRole(DEFAULT_ADMIN_ROLE, admin.address);
      const minterHasRole = await token.hasRole(MINTER_ROLE, minter.address);
      const pauserHasRole = await token.hasRole(PAUSER_ROLE, pauser.address);

      console.log("Expected: Admin should have DEFAULT_ADMIN_ROLE");
      console.log("Actual: Admin has role =", adminHasRole);
      console.log("Expected: Minter should have MINTER_ROLE");
      console.log("Actual: Minter has role =", minterHasRole);
      console.log("Expected: Pauser should have PAUSER_ROLE");
      console.log("Actual: Pauser has role =", pauserHasRole);

      expect(adminHasRole).to.be.true;
      expect(minterHasRole).to.be.true;
      expect(pauserHasRole).to.be.true;
    });
  });

  describe("Minting", function () {
    it("Should allow minter to mint tokens", async function () {
      console.log("\n=== Testing minting by authorized minter ===");
      const initialBalance = await token.balanceOf(user.address);
      console.log("Initial balance:", initialBalance.toString());
      
      await token.connect(minter).mint(user.address, 1000);
      const newBalance = await token.balanceOf(user.address);
      
      console.log("Expected balance after mint: 1000");
      console.log("Actual balance after mint:", newBalance.toString());
      expect(newBalance).to.equal(1000);
    });

    it("Should revert when non-minter tries to mint", async function () {
      console.log("\n=== Testing unauthorized minting ===");
      console.log("Attempting to mint with unauthorized account:", user.address);
      console.log("Expected: Should revert with UnauthorizedTokenManagement");
      
      await expect(
        token.connect(user).mint(user.address, 1000)
      ).to.be.reverted("Reverted");
      console.log("Result: Successfully reverted with UnauthorizedTokenManagement");
    });
  });

  describe("Burning", function () {
    beforeEach(async function () {
      console.log("\n=== Setting up burning test ===");
      const BURNER_ROLE = await token.BURNER_ROLE();
      console.log("Granting BURNER_ROLE to user:", user.address);
      await token.connect(admin).grantRole(BURNER_ROLE, user.address);
      
      console.log("Minting initial tokens to user");
      await token.connect(minter).mint(user.address, 1000);
      const initialBalance = await token.balanceOf(user.address);
      console.log("Initial balance:", initialBalance.toString());
    });

    it("Should allow burner to burn their tokens", async function () {
      console.log("\n=== Testing token burning ===");
      console.log("Expected balance after burning 500: 500");
      
      await token.connect(user).burn(500);
      const remainingBalance = await token.balanceOf(user.address);
      
      console.log("Actual balance after burning:", remainingBalance.toString());
      expect(remainingBalance).to.equal(500);
    });

    it("Should revert when burning zero amount", async function () {
      console.log("\n=== Testing zero amount burn ===");
      console.log("Attempting to burn zero tokens");
      console.log("Expected: Should revert with ZeroAmount");
      
      await expect(
        token.connect(user).burn(0)
      ).to.be.revertedWithCustomError(token, "ZeroAmount");
      console.log("Result: Successfully reverted with ZeroAmount");
    });
  });

  describe("Pausing", function () {
    it("Should allow pauser to pause and unpause", async function () {
      console.log("\n=== Testing pause functionality ===");
      const initialState = await token.paused();
      console.log("Initial pause state:", initialState);
      console.log("Expected states: true after pause, false after unpause");
      
      await token.connect(pauser).pause();
      const pausedState = await token.paused();
      console.log("State after pause:", pausedState);
      expect(pausedState).to.be.true;

      await token.connect(pauser).unpause();
      const unpausedState = await token.paused();
      console.log("State after unpause:", unpausedState);
      expect(unpausedState).to.be.false;
    });

    it("Should prevent transfers when paused", async function () {
      console.log("\n=== Testing transfer in paused state ===");
      console.log("Minting tokens to user");
      await token.connect(minter).mint(user.address, 1000);
      const balance = await token.balanceOf(user.address);
      console.log("User balance:", balance.toString());
      
      console.log("Pausing contract");
      await token.connect(pauser).pause();
      console.log("Expected: Should revert with ContractPaused");
      
      await expect(
        token.connect(user).transfer(owner.address, 100)
      ).to.be.revertedWithCustomError(token, "ContractPaused");
      console.log("Result: Successfully reverted with ContractPaused");
    });
  });
}); 