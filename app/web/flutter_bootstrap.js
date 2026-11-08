{{flutter_js}}
{{flutter_build_config}}

// The legacy service worker unregisters itself and reloads clients; do not register it.
_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      window.typhoonStartup.stage('正在准备显示内容…');
      const appRunner = await engineInitializer.initializeEngine();
      window.typhoonStartup.stage('正在打开实况页面…');
      await appRunner.runApp();
    } catch (_) {
      window.typhoonStartup.fail();
    }
  }
}).catch(() => window.typhoonStartup.fail());
