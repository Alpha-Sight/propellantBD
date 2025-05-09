import { Schema } from 'lisk-sdk';

export const roleAccountSchema: Schema = {
	$id: 'role/account',
	type: 'object',
	required: ['roles'],
	properties: {
		roles: {
			type: 'array',
			fieldNumber: 1,
			items: {
				type: 'string',
			},
			default: [],
		},
	},
};

export const roleAssetSchema: Schema = {
	$id: 'role/asset',
	type: 'object',
	required: ['address', 'roles', 'action'],
	properties: {
		address: {
			dataType: 'bytes',
			fieldNumber: 1,
			format: 'address',
		},
		roles: {
			type: 'array',
			fieldNumber: 2,
			items: {
				type: 'string',
			},
		},
		action: {
			type: 'string',
			fieldNumber: 3,
		},
	},
};
