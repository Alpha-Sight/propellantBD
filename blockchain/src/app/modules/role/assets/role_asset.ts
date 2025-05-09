import { BaseAsset, ApplyAssetContext, ValidateAssetContext } from 'lisk-sdk';
import { RoleAssetID, RoleAction, VALID_ROLES } from '../constants';
import { roleAssetSchema } from '../schemas';

interface RoleAssetProps {
	address: Buffer;
	roles: string[];
	action: string;
}

export class RoleAsset extends BaseAsset {
	public id = RoleAssetID.ASSIGN_REVOKE_ROLE;
	public name = 'roleAsset';
	public schema = roleAssetSchema;

	// Validate the asset payload
	public validate({ asset }: ValidateAssetContext<RoleAssetProps>): void {
		const { roles, action } = asset;

		// Check if the action is valid
		if (action !== RoleAction.ASSIGN && action !== RoleAction.REVOKE) {
			throw new Error(
				`Invalid action: ${action}. Valid actions are: ${RoleAction.ASSIGN}, ${RoleAction.REVOKE}`,
			);
		}

		// Check if all roles are valid
		for (const role of roles) {
			if (!VALID_ROLES.includes(role as any)) {
				throw new Error(`Invalid role: ${role}. Valid roles are: ${VALID_ROLES.join(', ')}`);
			}
		}
	}

	// Apply the changes to the state
	public async apply({
		asset,
		transaction,
		stateStore,
	}: ApplyAssetContext<RoleAssetProps>): Promise<void> {
		const { senderAddress } = transaction;
		const { address, roles, action } = asset;
		const addressStr = address.toString('hex');

		// Get or create the target account
		const targetAccountExists = await stateStore.account.has(address);
		let targetAccount;

		if (targetAccountExists) {
			targetAccount = await stateStore.account.get(address);
		} else {
			// Create a new account with default values if it doesn't exist
			targetAccount = {
				address,
				token: { balance: BigInt(0) },
				sequence: { nonce: BigInt(0) },
				keys: {},
				role: { roles: [] },
			};
		}

		// Get or set role property
		if (!targetAccount.role) {
			targetAccount.role = { roles: [] };
		}

		// For bootstrapping: The first account to assign admin role becomes admin
		// Otherwise, only admins can assign or revoke roles
		const isFirstAdmin = !targetAccountExists && roles.includes('admin');

		// Check if sender is an admin (unless bootstrapping the first admin)
		if (!isFirstAdmin) {
			const senderAccount = await stateStore.account.get(senderAddress);
			const isAdmin = senderAccount.role?.roles?.includes('admin') ?? false;

			if (!isAdmin) {
				throw new Error('Only admin can assign or revoke roles');
			}
		}

		// Apply the action
		if (action === RoleAction.ASSIGN) {
			// Add new roles (avoid duplicates)
			const existingRoles = targetAccount.role.roles || [];
			targetAccount.role.roles = [...new Set([...existingRoles, ...roles])];
		} else if (action === RoleAction.REVOKE) {
			// Remove the specified roles
			const existingRoles = targetAccount.role.roles || [];
			targetAccount.role.roles = existingRoles.filter(r => !roles.includes(r));
		}

		// Save the updated account
		await stateStore.account.set(address, targetAccount);
	}
}
