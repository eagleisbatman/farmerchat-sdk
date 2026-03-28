/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'FarmerChat SDK',
  tagline: 'AI-powered agricultural advisory chat for your app',
  url: 'https://sdk.farmerchat.digitalgreen.org',
  baseUrl: '/',
  onBrokenLinks: 'throw',
  organizationName: 'digitalgreen',
  projectName: 'farmerchat-sdk',

  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: './sidebars.js',
          routeBasePath: '/',
        },
        blog: false,
      }),
    ],
  ],

  /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
  themeConfig: {
    navbar: {
      title: 'FarmerChat SDK',
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docs',
          position: 'left',
          label: 'Quickstart',
        },
        {
          to: '/configuration/theming',
          label: 'Configuration',
          position: 'left',
        },
        {
          to: '/error-codes',
          label: 'API',
          position: 'left',
        },
        {
          href: 'https://github.com/digitalgreenorg/farmerchat-sdk',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            { label: 'Quickstart', to: '/quickstart/android-compose' },
            { label: 'Configuration', to: '/configuration/theming' },
            { label: 'Error Codes', to: '/error-codes' },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'Digital Green',
              href: 'https://www.digitalgreen.org',
            },
            {
              label: 'GitHub',
              href: 'https://github.com/digitalgreenorg/farmerchat-sdk',
            },
          ],
        },
      ],
      copyright: `Copyright ${new Date().getFullYear()} Digital Green Foundation.`,
    },
  },
};

module.exports = config;
