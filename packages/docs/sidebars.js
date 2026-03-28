/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docs: [
    'intro',
    {
      type: 'category',
      label: 'Quickstart',
      items: [
        'quickstart/android-compose',
        'quickstart/android-views',
        'quickstart/ios-swiftui',
        'quickstart/ios-uikit',
        'quickstart/react-native',
        'quickstart/web',
      ],
    },
    {
      type: 'category',
      label: 'Configuration',
      items: [
        'configuration/theming',
        'configuration/localization',
        'configuration/crash-reporting',
      ],
    },
    'error-codes',
  ],
};

module.exports = sidebars;
