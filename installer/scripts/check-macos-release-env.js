const requiredVars = [
  'APPLE_ID',
  'APPLE_APP_SPECIFIC_PASSWORD',
  'APPLE_TEAM_ID',
  'CSC_LINK',
  'CSC_KEY_PASSWORD',
];

const missing = requiredVars.filter((name) => !process.env[name]);

if (missing.length > 0) {
  console.error('macOS 正式发布缺少以下环境变量:');
  for (const name of missing) {
    console.error(`- ${name}`);
  }
  console.error('');
  console.error('请先配置 Apple 签名和 notarization 所需凭据，再运行 build:mac:release。');
  process.exit(1);
}

console.log('macOS 正式发布环境变量检查通过。');
