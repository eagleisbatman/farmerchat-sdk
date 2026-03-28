import type { FarmerChatConfig } from '@digitalgreenorg/farmerchat-core';

/**
 * FarmerChat Web SDK.
 * Embeddable chat widget using Shadow DOM for style isolation.
 */
export class FarmerChat {
  private config: FarmerChatConfig;
  private container: HTMLElement | null = null;

  constructor(config: FarmerChatConfig) {
    this.config = config;
  }

  /** Mount the chat widget to the DOM */
  mount(targetElement?: HTMLElement): void {
    // TODO: Create Shadow DOM container and render widget
    this.container = targetElement ?? document.body;
  }

  /** Open the chat widget */
  open(): void {
    // TODO: Show chat UI
  }

  /** Close the chat widget */
  close(): void {
    // TODO: Hide chat UI
  }

  /** Destroy and unmount the widget */
  destroy(): void {
    // TODO: Clean up
    this.container = null;
  }
}
