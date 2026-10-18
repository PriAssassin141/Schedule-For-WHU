/// Release identity bundled with the APK; never use installation/check time.
/// Keep this in sync with update-time in the published 更新日志.json.
const appReleaseUpdateTime = String.fromEnvironment(
  'APP_RELEASE_UPDATE_TIME',
  defaultValue: '202610181858',
);

const appUpdateShareUrl = 'https://pan.quark.cn/s/b57d9dfe897a';
