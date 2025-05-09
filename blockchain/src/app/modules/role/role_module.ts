import { BaseModule, codec, CryptoPublicKey, StateStore } from 'lisk-sdk';
import { RoleAsset } from './assets/role_asset';
import { MODULE_ID, MODULE_NAME, VALID_ROLES } from './constants';
import { roleAccountSchema } from './schemas';

export class RoleModule extends BaseModule {
	public id = MODULE_ID;
	public name = MODULE_NAME;
	public accountSchema = roleAccountSchema;

	// Register transactions/assets
	public registerAssets(): void {
		this.store.registerAsset(new RoleAsset());
	}

	// Public methods to be used by other modules
	public async hasRole(address: Buffer, role: string, stateStore: StateStore): Promise<boolean> {
		try {
			const account = await stateStore.account.get(address);
			if (!account.role) {
				return false;
			}
			return account.role.roles?.includes(role) ?? false;
		} catch (error) {
			return false;
		}
	}

	public async isAdmin(address: Buffer, stateStore: StateStore): Promise<boolean> {
		return this.hasRole(address, 'admin', stateStore);
	}

	// Get available roles
	public getValidRoles(): string[] {
		return [...VALID_ROLES];
	}
}
