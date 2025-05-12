import { expect } from "chai";
import hre from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { PropellantBDPaymaster, RoleModule, UserProfileModule } from "../../typechain-types";
import { IERC20 } from "../../typechain-types/@openzeppelin/contracts/token/ERC20/IERC20";
import { IEntryPoint } from "../../typechain-types/contracts/account/EntryPoint";

// We need a MockToken for testing
const MockTokenArtifact = {
  abi: [
    "function totalSupply() external view returns (uint256)",
    "function balanceOf(address account) external view returns (uint256)",
    "function transfer(address recipient, uint256 amount) external returns (bool)",
    "function allowance(address owner, address spender) external view returns (uint256)",
    "function approve(address spender, uint256 amount) external returns (bool)",
    "function transferFrom(address sender, address recipient, uint256 amount) external returns (bool)",
    "function mint(address to, uint256 amount) external",
    "event Transfer(address indexed from, address indexed to, uint256 value)",
    "event Approval(address indexed owner, address indexed spender, uint256 value)"
  ],
  bytecode: "0x608060405234801561001057600080fd5b50610804806100206000396000f3fe608060405234801561001057600080fd5b50600436106100935760003560e01c8063395093511161006657806339509351146101205780637e4e14cc1461013357806395d89b4114610146578063a457c2d714610157578063dd62ed3e1461016a57600080fd5b806306fdde0314610098578063095ea7b3146100b657806318160ddd146100d957806323b872dd146100eb575b600080fd5b6100a061017d565b6040516100ad9190610646565b60405180910390f35b6100c96100c4366004610627565b61020f565b60405190151581526020016100ad565b6100dd600181565b60405190815260200160405180910390f35b6100c96100f9366004610651565b610225565b6100c961011e366004610627565b610249565b6100c96101313660046106c2565b610267565b6101446101413660046106c2565b610296565b005b61015f60408051602081019091526000815290565b6040516100ad9190610767565b6100c9610297565b6060816000604051806040016040528060098152602001683637b1b5a1b7b73a3960b91b8152509050919050565b600061021c33848461029f565b50600192915050565b600061023284848461038c565b61024184848484610473565b5060019392505050565b600061025633848461038c565b61021c33848461038c565b600033610275818585610473565b610282818585610473565b505061029082868361029f565b506001949350505050565b505b5050565b5050565b60008060008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020548211156102ec57600080fd5b600060008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020549050600060008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000208390806001815401808255809150506001900390600052602060002001600090919091909150558273ffffffffffffffffffffffffffffffffffffffff1663a9059cbb87856040518363ffffffff1660e01b81526004016103c49291906107a0565b6020604051808303816000875af11580156103e3573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061040791906105fa565b507fb88d4fde9d292dab65316e4961e0e274fe8b7618cf64d54420fffc425b52d6c4858585604051610448939291909283526020830191909152604082015260600190565b60405180910390a16001925050509392505050565b600160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663a9059cbb8484846040518463ffffffff1660e01b81526004016104d2939291906107a0565b6020604051808303816000875af11580156104f1573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061051591906105fa565b507fe1cabf308c9fde1574e35b9b6364f54e8237d7f6e30e32ae1e8f60bfcb05f7d3838383604051610548939291906107a0565b60405180910390a16001905092915050565b600067ffffffffffffffff8084111561057357610573610797565b604051601f8501601f19908116603f0116810190828211818310171561059b5761059b610797565b816040528093508581528686860111156105b4578485600101945061059b565b600083526020838601011115610799578385820191505b509695505050505050565b80356001600160a01b03811681146105da57600080fd5b919050565b600060208083850312156105f257600080fd5b82359150610599565b60006020828403121561060c57600080fd5b8151801515811461061c57600080fd5b9392505050565b6000806040838503121561063a57600080fd5b610643836105c3565b946020939093013593505050565b602081526000825180602084015261066581604085016020870161077a565b601f01601f19169190910160400192915050565b80358015158114906105da57600080fd5b60008083601f84011261069957600080fd5b50813567ffffffffffffffff8111156106b157600080fd5b6020830191508360208285010111156106c957600080fd5b9250929050565b600080604083850312156106d557600080fd5b6106de836105c3565b9150602083013567ffffffffffffffff8111156106fa57600080fd5b8301601f8101851361070b57600080fd5b6107178582356020850161054c565b9150509250929050565b60008151808452602080851615156020850160018114610763578160a083860152610799565b600186018101519186019190915260408501529050610799565b60208152602082810151910152565b60005b8381101561079557818101518382015260200161077d565b50506000910152565b634e487b7160e01b600052604160045260246000fd5b6001600160a01b0384168152826020820152606060408201526000610799606083018461072a56fea2646970667358221220dc6e06d887b78f7e003c31f5e64d02c8e69a969e70f1dbbdb89a80b31ad5033364736f6c63430008110033"
};

describe("PropellantBDPaymaster", function () {
  // Fixture to deploy necessary contracts
  async function deployPaymasterFixture() {
    const [deployer, user1, user2] = await hre.ethers.getSigners();
    
    // Deploy RoleModule
    const RoleModuleFactory = await hre.ethers.getContractFactory("RoleModule");
    const roleModule = await RoleModuleFactory.deploy();
    
    // Deploy UserProfileModule
    const UserProfileModuleFactory = await hre.ethers.getContractFactory("UserProfileModule");
    const userProfileModule = await UserProfileModuleFactory.deploy(roleModule.target as unknown as string);
    
    // Deploy EntryPoint
    const EntryPointFactory = await hre.ethers.getContractFactory("PropellantBDEntryPoint");
    const entryPoint = await EntryPointFactory.deploy();
    
    // Deploy MockToken
    const MockTokenFactory = await hre.ethers.getContractFactory(
      MockTokenArtifact.abi,
      MockTokenArtifact.bytecode
    );
    const mockToken = await MockTokenFactory.deploy();
    
    // Deploy Paymaster
    const PaymasterFactory = await hre.ethers.getContractFactory("PropellantBDPaymaster");
    const paymaster = await PaymasterFactory.deploy(
      entryPoint.target as unknown as IEntryPoint, 
      userProfileModule.target as unknown as string,
      roleModule.target as unknown as string,
      mockToken.target as unknown as IERC20
    );
    
    // Get role constants
    const ADMIN_ROLE = await roleModule.ADMIN_ROLE();
    const TALENT_ROLE = await roleModule.TALENT_ROLE();
    const ORGANIZATION_ROLE = await roleModule.ORGANIZATION_ROLE();
    
    // Grant roles
    await roleModule.grantRole(ADMIN_ROLE, userProfileModule.target);
    await roleModule.grantRoleSafe(TALENT_ROLE, user1.address);
    
    // Create user profile
    await userProfileModule.connect(user1).createProfile(
      "User One", 
      "Test user", 
      "user1@example.com", 
      "avatar"
    );
    
    // Fund the paymaster with ETH
    await deployer.sendTransaction({
      to: paymaster.target,
      value: hre.ethers.parseEther("1.0")
    });
    
    return { 
      paymaster, 
      entryPoint, 
      roleModule, 
      userProfileModule, 
      mockToken,
      deployer, 
      user1, 
      user2,
      ADMIN_ROLE,
      TALENT_ROLE,
      ORGANIZATION_ROLE
    };
  }
  
  describe("Deployment", function () {
    it("Should deploy with correct parameters", async function () {
      const { paymaster, entryPoint, roleModule, userProfileModule, mockToken } = 
        await loadFixture(deployPaymasterFixture);
      
      expect(paymaster.target).to.not.equal(hre.ethers.ZeroAddress);
      expect(await paymaster.entryPoint()).to.equal(entryPoint.target);
      expect(await paymaster.profileModule()).to.equal(userProfileModule.target);
      expect(await paymaster.roleModule()).to.equal(roleModule.target);
      expect(await paymaster.token()).to.equal(mockToken.target);
    });
    
    it("Should initialize with default values", async function () {
      const { paymaster } = await loadFixture(deployPaymasterFixture);
      
      expect(await paymaster.isAcceptingOperations()).to.be.true;
      expect(await paymaster.maxGasLimit()).to.equal(1_000_000);
      expect(await paymaster.dailySponsorshipLimit()).to.equal(hre.ethers.parseEther("0.01"));
    });
  });
  
  describe("Configuration", function () {
    it("Should allow owner to set sponsorship limit", async function () {
      const { paymaster } = await loadFixture(deployPaymasterFixture);
      
      const newLimit = hre.ethers.parseEther("0.02");
      
      await expect(paymaster.setDailySponsorshipLimit(newLimit))
        .to.emit(paymaster, "SponsorshipLimitUpdated")
        .withArgs(newLimit);
      
      expect(await paymaster.dailySponsorshipLimit()).to.equal(newLimit);
    });
    
    it("Should allow owner to set max gas limit", async function () {
      const { paymaster } = await loadFixture(deployPaymasterFixture);
      
      const newLimit = 2_000_000;
      
      await expect(paymaster.setMaxGasLimit(newLimit))
        .to.emit(paymaster, "MaxGasLimitUpdated")
        .withArgs(newLimit);
      
      expect(await paymaster.maxGasLimit()).to.equal(newLimit);
    });
    
    it("Should allow owner to set accepting operations", async function () {
      const { paymaster } = await loadFixture(deployPaymasterFixture);
      
      await expect(paymaster.setAcceptingOperations(false))
        .to.emit(paymaster, "AcceptingOperationsUpdated")
        .withArgs(false);
      
      expect(await paymaster.isAcceptingOperations()).to.be.false;
    });
    
    it("Should prevent non-owners from updating configuration", async function () {
      const { paymaster, user1 } = await loadFixture(deployPaymasterFixture);
      
      await expect(
        paymaster.connect(user1).setDailySponsorshipLimit(hre.ethers.parseEther("0.02"))
      ).to.be.revertedWith("Ownable: caller is not the owner");
      
      await expect(
        paymaster.connect(user1).setMaxGasLimit(2_000_000)
      ).to.be.revertedWith("Ownable: caller is not the owner");
      
      await expect(
        paymaster.connect(user1).setAcceptingOperations(false)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
  
  describe("Deposit and Withdrawal", function () {
    it("Should allow depositing funds", async function () {
      const { paymaster, deployer } = await loadFixture(deployPaymasterFixture);
      
      const depositAmount = hre.ethers.parseEther("0.5");
      
      const initialBalance = await hre.ethers.provider.getBalance(paymaster.target);
      
      await paymaster.deposit({ value: depositAmount });
      
      const newBalance = await hre.ethers.provider.getBalance(paymaster.target);
      expect(newBalance - initialBalance).to.equal(depositAmount);
    });
    
    it("Should allow owner to withdraw from EntryPoint", async function () {
      const { paymaster, entryPoint, deployer } = await loadFixture(deployPaymasterFixture);
      
      // First deposit some ETH to the EntryPoint
      const depositAmount = hre.ethers.parseEther("0.5");
      await paymaster.deposit({ value: depositAmount });
      
      // Try to withdraw some funds
      const withdrawAmount = hre.ethers.parseEther("0.2");
      
      const initialBalance = await hre.ethers.provider.getBalance(deployer.address);
      
      const tx = await paymaster.withdrawFromEntryPoint(withdrawAmount);
      const receipt = await tx.wait();
      
      // Calculate gas cost
      const gasCost = receipt!.gasUsed * receipt!.gasPrice;
      
      // Check balance increased minus gas costs
      const newBalance = await hre.ethers.provider.getBalance(deployer.address);
      expect(newBalance).to.be.closeTo(
        initialBalance + withdrawAmount - gasCost,
        hre.ethers.parseEther("0.0001") // Allow for small differences in gas estimation
      );
    });
    
    it("Should prevent non-owners from withdrawing funds", async function () {
      const { paymaster, user1 } = await loadFixture(deployPaymasterFixture);
      
      await expect(
        paymaster.connect(user1).withdrawFromEntryPoint(hre.ethers.parseEther("0.1"))
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
  
  // Note: Testing the full UserOperation validation flow with ERC-4337 requires 
  // complex setup and mocking of EntryPoint behavior, which is beyond the scope
  // of basic unit tests.
});