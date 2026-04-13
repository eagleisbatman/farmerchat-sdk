import type { FarmerChatConfig } from '@digitalgreenorg/farmerchat-core';
import { ChatWidget } from './widget/ChatWidget';

/**
 * FarmerChat Web SDK.
 *
 * Embeds an AI-powered agricultural chat widget into any web page.
 * Uses Shadow DOM for full CSS isolation from the host application.
 *
 * @example
 * ```ts
 * import { FarmerChat } from '@digitalgreenorg/farmerchat-web';
 *
 * const chat = new FarmerChat({
 *   apiKey: 'fc_test_...',
 *   headerTitle: 'Farm Advisor',
 * });
 * chat.mount();   // Attaches FAB + panel to <body>
 * ```
 */
export class FarmerChat {
  private widget: ChatWidget | null = null;
  private hostEl: HTMLElement | null = null;
  private readonly config: FarmerChatConfig;

  constructor(config: FarmerChatConfig) {
    if (!config.apiKey) throw new Error('[FarmerChat] apiKey is required');
    this.config = {
      baseUrl: 'https://farmerchat.farmstack.co/mobile-app-dev',
      historyEnabled: true,
      profileEnabled: true,
      showPoweredBy: true,
      ...config,
    };
  }

  /**
   * Mount the chat widget to the DOM.
   * @param target Optional host element. Defaults to document.body.
   */
  mount(target?: HTMLElement): void {
    if (this.widget) return; // Already mounted

    this.hostEl = target ?? document.body;

    // Create a dedicated host element for the Shadow DOM
    const host = document.createElement('div');
    host.setAttribute('id', 'farmerchat-sdk-root');
    host.style.cssText = 'position:fixed;z-index:2147483645;top:0;left:0;width:0;height:0;';
    this.hostEl.appendChild(host);

    this.widget = new ChatWidget(this.config, host);
  }

  /** Open the chat panel. */
  open(): void { this.widget?.open(); }

  /** Close the chat panel. */
  close(): void { this.widget?.close(); }

  /** Toggle the chat panel open/closed. */
  toggle(): void { this.widget?.toggleOpen(); }

  /** Start a fresh conversation (clears messages and resets conversation ID). */
  newConversation(): void { this.widget?.startNewConversation(); }

  /** Destroy and remove the widget from the DOM. */
  destroy(): void {
    const host = this.hostEl?.querySelector('#farmerchat-sdk-root');
    host?.remove();
    this.widget = null;
    this.hostEl = null;
  }
}
