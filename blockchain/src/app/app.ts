import { Application, PartialApplicationConfig, utils } from 'lisk-sdk';
import { registerModules } from './modules';
import { registerPlugins } from './plugins';

export const getApplication = (config: PartialApplicationConfig): Application => {
	const { genesisConfig, ...appConfig } = config;
	const app = Application.defaultApplication({
		...appConfig,
		genesis: { ...genesisConfig },
	});

	registerModules(app);
	registerPlugins(app);

	return app;
};
