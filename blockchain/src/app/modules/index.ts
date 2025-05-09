import { Application } from 'lisk-sdk';
import { RoleModule } from './role/role_module';

export const registerModules = (app: Application): void => {
	app.registerModule(new RoleModule());
};
