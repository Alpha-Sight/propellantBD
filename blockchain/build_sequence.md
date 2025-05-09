# Lisk Blockchain Module Development Sequence

When building a blockchain system with multiple modules, it's important to follow a logical sequence that respects dependencies and provides a foundation for subsequent modules. Here's the recommended sequence for building the modules in your Lisk sidechain project:

## Recommended Build Sequence

1. **RoleModule** (First)

   - Defines fundamental roles (Admin, Talents, Organizations)
   - Provides the permission foundation for all other modules
   - Simplest to implement with fewest dependencies

2. **UserProfileModule** (Second)

   - Creates the foundation for user identity
   - References roles defined in the RoleModule
   - Core module that other modules will depend on

3. **StorageModule** (Third)

   - Provides the IPFS storage infrastructure
   - Relatively independent but will be used by subsequent modules
   - Enables document and credential storage capabilities

4. **CredentialVerificationModule** (Fourth)

   - Depends on UserProfileModule for identity
   - Uses RoleModule for issuer permissions
   - May leverage StorageModule for credential content

5. **Account Abstraction Module (ERC-4337)** (Last)
   - Most complex module with multiple components
   - Integrates with all previous modules
   - Includes EntryPoint, Account Contracts, Bundler, Factory, and Paymaster
