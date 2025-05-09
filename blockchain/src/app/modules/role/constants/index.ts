export const MODULE_NAME = 'role';
export const MODULE_ID = 1000;

export enum RoleAssetID {
	ASSIGN_REVOKE_ROLE = 0,
}

export enum RoleAction {
	ASSIGN = 'assign',
	REVOKE = 'revoke',
}

export enum RoleType {
	ADMIN = 'admin',
	TALENT = 'talent',
	ORGANIZATION = 'organization',
	GUEST = 'guest',
}

export const VALID_ROLES = [RoleType.ADMIN, RoleType.TALENT, RoleType.ORGANIZATION, RoleType.GUEST];
