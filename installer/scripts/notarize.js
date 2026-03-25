const path = require('path');
const { notarize } = require('@electron/notarize');

exports.default = async function notarizeApp(context) {
  if (context.electronPlatformName !== 'darwin') {
    return;
  }

  const requiredVars = ['APPLE_ID', 'APPLE_APP_SPECIFIC_PASSWORD', 'APPLE_TEAM_ID'];
  const missing = requiredVars.filter((name) => !process.env[name]);

  if (missing.length > 0) {
    console.warn(
      `跳过 notarization：缺少环境变量 ${missing.join(', ')}。`
    );
    console.warn('这适合本地调试构建，不适合公开发布。');
    return;
  }

  const appName = context.packager.appInfo.productFilename;
  const appPath = path.join(context.appOutDir, `${appName}.app`);

  console.log(`开始 notarize: ${appPath}`);

  await notarize({
    tool: 'notarytool',
    appBundleId: context.packager.appInfo.id,
    appPath,
    appleId: process.env.APPLE_ID,
    appleIdPassword: process.env.APPLE_APP_SPECIFIC_PASSWORD,
    teamId: process.env.APPLE_TEAM_ID,
  });

  console.log('notarization 完成。');
};
