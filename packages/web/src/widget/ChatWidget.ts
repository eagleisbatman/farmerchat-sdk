import type { FarmerChatConfig } from '@digitalgreenorg/farmerchat-core';
import { ApiClient } from '../api/client';
import { TokenStore } from '../api/tokenStore';
import { WIDGET_CSS } from './styles';
import type {
  SupportedLanguage, SupportedLanguageGroup,
  ConversationListItem, HistoryMessageItem, FollowUpOption, TextPromptChunk,
} from '../api/models';

// ── Types ────────────────────────────────────────────────────────────────────

type Screen = 'onboarding' | 'chat' | 'history' | 'profile';

interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  text: string;
  followUps: FollowUpOption[];
  serverMessageId?: string;
  contentProviderLogo?: string;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

let idCounter = 0;
function uid(): string { return `fc-${++idCounter}-${Date.now()}`; }

function escHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
          .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function markdownToHtml(md: string): string {
  let s = escHtml(md);
  // Code blocks
  s = s.replace(/```[\s\S]*?```/g, m => `<pre><code>${m.slice(3, -3).replace(/^\w+\n/, '')}</code></pre>`);
  // Inline code
  s = s.replace(/`([^`]+)`/g, '<code>$1</code>');
  // Bold
  s = s.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  // Italic
  s = s.replace(/\*(.+?)\*/g, '<em>$1</em>');
  // Unordered list
  s = s.replace(/^[\*\-] (.+)$/gm, '<li>$1</li>').replace(/(<li>.*<\/li>)/s, '<ul>$1</ul>');
  // Ordered list
  s = s.replace(/^\d+\. (.+)$/gm, '<li>$1</li>');
  // Paragraphs
  s = s.split(/\n{2,}/).map(p => p.trim() ? `<p>${p.replace(/\n/g, '<br>')}</p>` : '').join('');
  return s || `<p>${escHtml(md)}</p>`;
}

function formatRelativeDate(dateStr?: string | null): string {
  if (!dateStr) return '';
  const normalized = dateStr.replace('T', ' ').split('Z')[0]!.split('+')[0]!.trim().slice(0, 19);
  const date = new Date(normalized.replace(' ', 'T') + 'Z');
  if (isNaN(date.getTime())) return dateStr;
  const secs = (Date.now() - date.getTime()) / 1000;
  if (secs < 0)     return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
  if (secs < 60)    return 'Just now';
  if (secs < 3600)  return `${Math.floor(secs / 60)}m ago`;
  if (secs < 86400) return `${Math.floor(secs / 3600)}h ago`;
  if (secs < 172800) return 'Yesterday';
  if (secs < 604800) return `${Math.floor(secs / 86400)}d ago`;
  return date.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

// SVG icons
const ICON = {
  send: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M2.01 21 23 12 2.01 3 2 10l15 2-15 2z"/></svg>`,
  translate: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12.87 15.07l-2.54-2.51.03-.03A17.52 17.52 0 0 0 14.07 6H17V4h-7V2H8v2H1v2h11.17C11.5 7.92 10.44 9.75 9 11.35 8.07 10.32 7.3 9.19 6.69 8h-2c.73 1.63 1.73 3.17 2.98 4.56l-5.09 5.02L4 19l5-5 3.11 3.11.76-2.04zM18.5 10h-2L12 22h2l1.12-3h4.75L21 22h2l-4.5-12zm-2.62 7l1.62-4.33L19.12 17h-3.24z"/></svg>`,
  history: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M13 3a9 9 0 0 0-9 9H1l3.89 3.89.07.14L9 12H6c0-3.87 3.13-7 7-7s7 3.13 7 7-3.13 7-7 7c-1.93 0-3.68-.79-4.94-2.06l-1.42 1.42A8.954 8.954 0 0 0 13 21a9 9 0 0 0 0-18zm-1 5v5l4.28 2.54.72-1.21-3.5-2.08V8H12z"/></svg>`,
  back: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"/></svg>`,
  chat: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"/></svg>`,
  close: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>`,
  plus: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/></svg>`,
  check: `<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>`,
};

// ── ChatWidget ─────────────────────────────────────────────────────────────────

export class ChatWidget {
  private root: ShadowRoot;
  private host: HTMLElement;
  private config: FarmerChatConfig;
  private api: ApiClient;
  private isOpen = false;

  // State
  private screen: Screen = 'chat';
  private messages: ChatMessage[] = [];
  private conversationId: string | null = null;
  private isStreaming = false;
  private streamingId: string | null = null;
  private abortStream: (() => void) | null = null;
  private lastError: string | null = null;
  private lastQuery: string | null = null;
  private languageGroups: SupportedLanguageGroup[] = [];
  private conversations: ConversationListItem[] = [];
  private filteredConversations: ConversationListItem[] = [];
  private historyLoading = false;
  private langLoading = false;
  private pickedLanguage = false;

  constructor(config: FarmerChatConfig, host: HTMLElement) {
    this.config = config;
    this.host = host;
    this.root = host.attachShadow({ mode: 'open' });
    this.api = new ApiClient(
      config.baseUrl ?? 'https://farmerchat.farmstack.co/mobile-app-dev',
      config.apiKey,
    );

    const saved = TokenStore.selectedLanguage;
    if (saved && saved !== 'en') this.pickedLanguage = true;
    this.screen = TokenStore.isOnboardingDone ? 'chat' : 'onboarding';

    this.render();
    this.bindEvents();

    // Pre-fetch tokens silently
    this.api.ensureTokens().catch(() => {});
  }

  // ── Render ────────────────────────────────────────────────────────────────

  private render(): void {
    const title = this.config.headerTitle ?? 'FarmerChat AI';
    const panelHidden = this.isOpen ? '' : 'fc-hidden';

    this.root.innerHTML = `
      <style>${WIDGET_CSS}</style>
      <div class="fc-widget">
        <div class="fc-panel ${panelHidden}" id="fc-panel">
          ${this.renderToolbar(title)}
          <div class="fc-screen" id="fc-screen">
            ${this.renderCurrentScreen()}
          </div>
        </div>
        ${this.renderFab()}
      </div>`;
  }

  private renderToolbar(title: string): string {
    const screen = this.screen;
    if (screen === 'onboarding') return '';

    const isSubScreen = screen === 'history' || screen === 'profile';
    const subTitle = screen === 'history' ? 'Conversation History' : 'Language';

    if (isSubScreen) {
      return `
        <div class="fc-toolbar" id="fc-toolbar">
          <button class="fc-icon-btn" id="fc-btn-back" title="Back">${ICON.back}</button>
          <div class="fc-toolbar-info">
            <div class="fc-toolbar-title">${escHtml(subTitle)}</div>
            <div class="fc-toolbar-sub">${screen === 'history' ? 'Tap a conversation to continue' : 'Choose your preferred language'}</div>
          </div>
          ${screen === 'history' ? `<button class="fc-icon-btn" id="fc-btn-new-chat" title="New chat">${ICON.plus}</button>` : ''}
        </div>`;
    }

    return `
      <div class="fc-toolbar" id="fc-toolbar">
        <div class="fc-avatar">🌱</div>
        <div class="fc-toolbar-info">
          <div class="fc-toolbar-title">
            ${escHtml(title)}
            <span class="fc-online-dot"></span>
          </div>
          <div class="fc-toolbar-sub">Smart Farming Assistant</div>
        </div>
        ${(this.config.profileEnabled !== false) ? `<button class="fc-icon-btn" id="fc-btn-lang" title="Change language">${ICON.translate}</button>` : ''}
        ${(this.config.historyEnabled !== false) ? `<button class="fc-icon-btn" id="fc-btn-history" title="History">${ICON.history}</button>` : ''}
        <button class="fc-icon-btn" id="fc-btn-close" title="Close">${ICON.close}</button>
      </div>`;
  }

  private renderCurrentScreen(): string {
    switch (this.screen) {
      case 'onboarding': return this.renderOnboarding();
      case 'chat':       return this.renderChat();
      case 'history':    return this.renderHistory();
      case 'profile':    return this.renderProfile();
    }
  }

  // ── Onboarding ─────────────────────────────────────────────────────────────

  private renderOnboarding(): string {
    const allLangs = this.languageGroups.flatMap(g => g.languages);
    const selected = TokenStore.selectedLanguage;

    const langItems = allLangs.length
      ? allLangs.map(l => `
          <div class="fc-lang-item${l.code === selected ? ' selected' : ''}"
               data-code="${escHtml(l.code)}" data-id="${l.id}">
            <div class="fc-lang-names">
              <div class="fc-lang-native">${escHtml(l.display_name || l.name)}</div>
              ${l.display_name && l.name !== l.display_name ? `<div class="fc-lang-en">${escHtml(l.name)}</div>` : ''}
            </div>
            ${l.code === selected ? `<div class="fc-check">${ICON.check}</div>` : ''}
          </div>`).join('')
      : `<div class="fc-spinner-wrap"><div class="fc-spinner"></div></div>`;

    return `
      <div class="fc-onboard">
        <div class="fc-onboard-hero">
          <div class="fc-onboard-emoji">🌾</div>
          <div class="fc-onboard-title">Welcome to FarmerChat</div>
          <div class="fc-onboard-sub">Choose your language to get started with AI-powered farming advice.</div>
        </div>
        <div class="fc-onboard-lang-list" id="fc-onboard-langs">${langItems}</div>
        <button class="fc-start-btn" id="fc-start-btn" ${this.pickedLanguage ? '' : 'disabled'}>Get Started</button>
      </div>`;
  }

  // ── Chat ────────────────────────────────────────────────────────────────────

  private renderChat(): string {
    const msgHtml = this.messages.length
      ? this.messages.map(m => this.renderMessage(m)).join('')
      : this.renderEmptyState();

    const streamingBubble = this.isStreaming && this.streamingId
      ? `<div class="fc-bubble-row" id="fc-streaming-row">
          <div class="fc-bot-avatar">🌱</div>
          <div class="fc-bubble assistant" id="fc-streaming-bubble">
            <div class="fc-typing">
              <div class="fc-dot"></div><div class="fc-dot"></div><div class="fc-dot"></div>
            </div>
          </div>
         </div>`
      : '';

    const errorHtml = this.lastError ? `
      <div class="fc-error" id="fc-error-banner">
        ⚠ ${escHtml(this.lastError)}
        ${this.lastQuery ? `<button id="fc-btn-retry">Retry</button>` : ''}
      </div>` : '';

    return `
      <div class="fc-messages" id="fc-messages">
        ${msgHtml}
        ${streamingBubble}
      </div>
      ${errorHtml}
      <div class="fc-input-bar">
        <textarea class="fc-input" id="fc-input" placeholder="Ask about crops, weather, pests…" rows="1"></textarea>
        <button class="fc-send-btn" id="fc-send-btn" ${this.isStreaming ? 'disabled' : ''}>
          ${ICON.send}
        </button>
      </div>`;
  }

  private renderMessage(msg: ChatMessage): string {
    if (msg.role === 'user') {
      return `<div class="fc-bubble-row user">
        <div class="fc-bubble user">${markdownToHtml(msg.text)}</div>
      </div>`;
    }
    const followUpsHtml = msg.followUps.length
      ? `<div class="fc-followups">${msg.followUps.map(f => `
          <button class="fc-chip" data-fid="${escHtml(f.follow_up_question_id)}" data-ftext="${escHtml(f.question)}">
            💬 ${escHtml(f.question)}
          </button>`).join('')}</div>`
      : '';
    return `<div class="fc-bubble-row">
      <div class="fc-bot-avatar">🌱</div>
      <div class="fc-bubble assistant">
        ${markdownToHtml(msg.text)}
        ${followUpsHtml}
      </div>
    </div>`;
  }

  private renderEmptyState(): string {
    return `<div class="fc-empty">
      <div class="fc-empty-emoji">🌾</div>
      <div class="fc-empty-title">Ask FarmerChat anything</div>
      <div class="fc-empty-sub">Get expert advice on crops, diseases, weather, markets, and more.</div>
    </div>`;
  }

  // ── History ─────────────────────────────────────────────────────────────────

  private renderHistory(): string {
    const list = this.filteredConversations;
    let listHtml = '';

    if (this.historyLoading) {
      listHtml = `<div class="fc-spinner-wrap"><div class="fc-spinner"></div></div>`;
    } else if (list.length === 0) {
      listHtml = `<div class="fc-empty"><div class="fc-empty-emoji">📋</div>
        <div class="fc-empty-title">No conversations yet</div>
        <div class="fc-empty-sub">Start a new chat to begin.</div></div>`;
    } else {
      // Group by grouping field
      const groups: Record<string, ConversationListItem[]> = {};
      for (const c of list) {
        const g = c.grouping ?? 'Older';
        if (!groups[g]) groups[g] = [];
        groups[g]!.push(c);
      }
      for (const [label, items] of Object.entries(groups)) {
        listHtml += `<div class="fc-section-label">${escHtml(label)}</div>`;
        for (const c of items) {
          const emoji = '🌾';
          const title = c.conversation_title?.trim() || 'Conversation';
          const date  = formatRelativeDate(c.created_on);
          listHtml += `
            <div class="fc-conv-item" data-cid="${escHtml(c.conversation_id)}">
              <div class="fc-conv-icon">${emoji}</div>
              <div class="fc-conv-info">
                <div class="fc-conv-title">${escHtml(title)}</div>
                <div class="fc-conv-date">${escHtml(date)}</div>
              </div>
              <span class="fc-conv-arrow">›</span>
            </div>`;
        }
      }
    }

    return `
      <div class="fc-list-header">
        <input class="fc-search" id="fc-history-search" type="text"
               placeholder="Search conversations…" value="">
      </div>
      <div class="fc-conv-list" id="fc-conv-list">${listHtml}</div>`;
  }

  // ── Profile / Language ───────────────────────────────────────────────────────

  private renderProfile(): string {
    const allLangs = this.languageGroups.flatMap(g => g.languages);
    const selected = TokenStore.selectedLanguage;

    const items = this.langLoading
      ? `<div class="fc-spinner-wrap"><div class="fc-spinner"></div></div>`
      : allLangs.map(l => `
          <div class="fc-lang-item${l.code === selected ? ' selected' : ''}"
               data-code="${escHtml(l.code)}" data-id="${l.id}">
            <div class="fc-lang-names">
              <div class="fc-lang-native">${escHtml(l.display_name || l.name)}</div>
              ${l.display_name && l.name !== l.display_name ? `<div class="fc-lang-en">${escHtml(l.name)}</div>` : ''}
            </div>
            ${l.code === selected ? `<div class="fc-check">${ICON.check}</div>` : ''}
          </div>`).join('');

    const footer = (this.config.showPoweredBy !== false)
      ? `<div class="fc-profile-footer">Powered by FarmerChat</div>` : '';

    return `<div class="fc-lang-list" id="fc-lang-list">${items}</div>${footer}`;
  }

  // ── FAB ──────────────────────────────────────────────────────────────────────

  private renderFab(): string {
    const icon = this.isOpen ? ICON.close : ICON.chat;
    return `<button class="fc-fab" id="fc-fab" title="FarmerChat">${icon}</button>`;
  }

  // ── Events ────────────────────────────────────────────────────────────────────

  private bindEvents(): void {
    this.root.addEventListener('click', (e) => this.handleClick(e));
    this.root.addEventListener('input', (e) => this.handleInput(e));
    this.root.addEventListener('keydown', (e) => {
      const el = e.target as HTMLElement;
      if (el.id === 'fc-input' && (e as KeyboardEvent).key === 'Enter' && !(e as KeyboardEvent).shiftKey) {
        e.preventDefault();
        this.sendMessage();
      }
    });
  }

  private handleClick(e: Event): void {
    const t = e.target as HTMLElement;
    const btn = t.closest('[id]') as HTMLElement | null;
    const id = btn?.id;

    if (id === 'fc-fab')           { this.toggleOpen(); return; }
    if (id === 'fc-btn-close')     { this.close(); return; }
    if (id === 'fc-btn-history')   { this.navigateTo('history'); return; }
    if (id === 'fc-btn-lang')      { this.navigateTo('profile'); return; }
    if (id === 'fc-btn-back')      { this.navigateTo('chat'); return; }
    if (id === 'fc-btn-new-chat')  { this.startNewConversation(); return; }
    if (id === 'fc-send-btn')      { this.sendMessage(); return; }
    if (id === 'fc-btn-retry')     { this.retryLast(); return; }
    if (id === 'fc-start-btn')     { this.completeOnboarding(); return; }

    // Follow-up chip
    const chip = t.closest('.fc-chip') as HTMLElement | null;
    if (chip) { this.sendFollowUp(chip.dataset['fid'] ?? '', chip.dataset['ftext'] ?? ''); return; }

    // Conversation item
    const conv = t.closest('.fc-conv-item') as HTMLElement | null;
    if (conv) { this.loadConversation(conv.dataset['cid'] ?? ''); return; }

    // Language item (in profile screen)
    const langItem = t.closest('.fc-lang-item') as HTMLElement | null;
    if (langItem && (this.screen === 'profile' || this.screen === 'onboarding')) {
      this.selectLanguage(langItem.dataset['code'] ?? '', Number(langItem.dataset['id']));
      return;
    }
  }

  private handleInput(e: Event): void {
    const t = e.target as HTMLElement;
    if (t.id === 'fc-history-search') {
      const q = (t as HTMLInputElement).value.toLowerCase();
      this.filteredConversations = q
        ? this.conversations.filter(c => c.conversation_title?.toLowerCase().includes(q))
        : [...this.conversations];
      const list = this.root.getElementById('fc-conv-list');
      if (list) list.innerHTML = this.renderHistoryListInner();
    }
    if (t.id === 'fc-input') {
      // Auto-resize
      const ta = t as HTMLTextAreaElement;
      ta.style.height = 'auto';
      ta.style.height = Math.min(ta.scrollHeight, 100) + 'px';
    }
  }

  private renderHistoryListInner(): string {
    const list = this.filteredConversations;
    if (!list.length) return `<div class="fc-empty"><div class="fc-empty-emoji">🔍</div>
      <div class="fc-empty-title">No results</div></div>`;
    const groups: Record<string, ConversationListItem[]> = {};
    for (const c of list) { const g = c.grouping ?? 'Older'; if (!groups[g]) groups[g] = []; groups[g]!.push(c); }
    let html = '';
    for (const [label, items] of Object.entries(groups)) {
      html += `<div class="fc-section-label">${escHtml(label)}</div>`;
      for (const c of items) {
        const title = c.conversation_title?.trim() || 'Conversation';
        const date  = formatRelativeDate(c.created_on);
        html += `<div class="fc-conv-item" data-cid="${escHtml(c.conversation_id)}">
          <div class="fc-conv-icon">🌾</div>
          <div class="fc-conv-info">
            <div class="fc-conv-title">${escHtml(title)}</div>
            <div class="fc-conv-date">${escHtml(date)}</div>
          </div>
          <span class="fc-conv-arrow">›</span>
        </div>`;
      }
    }
    return html;
  }

  // ── Navigation ───────────────────────────────────────────────────────────────

  private navigateTo(screen: Screen): void {
    this.screen = screen;
    if (screen === 'history') this.fetchHistory();
    if (screen === 'profile' || screen === 'onboarding') this.fetchLanguages();
    this.rerender();
  }

  // ── Open / Close ──────────────────────────────────────────────────────────────

  toggleOpen(): void { this.isOpen ? this.close() : this.open(); }

  open(): void {
    this.isOpen = true;
    if (this.screen === 'onboarding' && this.languageGroups.length === 0) this.fetchLanguages();
    this.rerender();
  }

  close(): void { this.isOpen = false; this.rerender(); }

  // ── Onboarding ────────────────────────────────────────────────────────────────

  private selectLanguage(code: string, langId: number): void {
    TokenStore.setLanguage(code);
    this.pickedLanguage = true;
    // Update server asynchronously
    this.api.setPreferredLanguage(String(langId)).catch(() => {});
    this.rerender();
  }

  private completeOnboarding(): void {
    if (!this.pickedLanguage) return;
    TokenStore.setOnboardingDone();
    this.screen = 'chat';
    this.rerender();
  }

  // ── Send message ──────────────────────────────────────────────────────────────

  private sendMessage(): void {
    const input = this.root.getElementById('fc-input') as HTMLTextAreaElement | null;
    const text  = input?.value.trim();
    if (!text || this.isStreaming) return;
    input!.value = '';
    input!.style.height = 'auto';
    this.lastError = null;
    this.lastQuery = text;
    this.doSend(text);
  }

  private sendFollowUp(followUpId: string, text: string): void {
    if (this.isStreaming) return;
    this.lastError = null;
    this.lastQuery = text;
    if (this.conversationId) {
      this.api.trackFollowUpClick(this.conversationId, followUpId, text).catch(() => {});
    }
    this.doSend(text);
  }

  private retryLast(): void {
    if (this.lastQuery) { this.lastError = null; this.doSend(this.lastQuery); }
  }

  private doSend(text: string): void {
    const userMsg: ChatMessage = { id: uid(), role: 'user', text, followUps: [] };
    this.messages.push(userMsg);
    this.isStreaming = true;
    this.streamingId = uid();
    this.rerender();
    this.scrollToBottom();

    (async () => {
      try {
        await this.api.ensureTokens();
        if (!this.conversationId) {
          const nc = await this.api.newConversation();
          this.conversationId = nc.conversation_id;
        }

        let accumulated = '';
        let serverMsgId: string | undefined;
        let followUps: FollowUpOption[] = [];
        const msgRefId = uid();

        this.abortStream = this.api.streamTextPrompt(
          this.conversationId,
          text,
          msgRefId,
          (chunk: TextPromptChunk) => {
            if (chunk.text) { accumulated += chunk.text; }
            if (chunk.message_id) serverMsgId = chunk.message_id;
            if (chunk.follow_up_questions) followUps = chunk.follow_up_questions;
            this.updateStreamingBubble(accumulated);
          },
          () => {
            // Done
            const assistantMsg: ChatMessage = {
              id: this.streamingId!,
              role: 'assistant',
              text: accumulated || '…',
              followUps,
              serverMessageId: serverMsgId,
            };
            this.messages.push(assistantMsg);
            this.isStreaming = false;
            this.streamingId = null;
            this.abortStream = null;
            this.rerender();
            this.scrollToBottom();
          },
          (err: Error) => {
            this.lastError = err.message.includes('400') || err.message.includes('401')
              ? 'Could not connect to FarmerChat. Please try again.'
              : err.message;
            this.isStreaming = false;
            this.streamingId = null;
            this.abortStream = null;
            this.rerender();
          },
        );
      } catch (err) {
        this.lastError = (err as Error).message;
        this.isStreaming = false;
        this.streamingId = null;
        this.rerender();
      }
    })();
  }

  private updateStreamingBubble(text: string): void {
    const bubble = this.root.getElementById('fc-streaming-bubble');
    if (!bubble) return;
    bubble.innerHTML = markdownToHtml(text || '');
    this.scrollToBottom();
  }

  // ── History ────────────────────────────────────────────────────────────────────

  private fetchHistory(): void {
    this.historyLoading = true;
    this.conversations = [];
    this.filteredConversations = [];
    this.api.getConversationList()
      .then(list => {
        this.conversations = Array.isArray(list) ? list : [];
        this.filteredConversations = [...this.conversations];
        this.historyLoading = false;
        if (this.screen === 'history') this.rerender();
      })
      .catch(() => { this.historyLoading = false; if (this.screen === 'history') this.rerender(); });
  }

  private loadConversation(conversationId: string): void {
    this.screen = 'chat';
    this.conversationId = conversationId;
    this.messages = [];
    this.rerender();

    this.api.getChatHistory(conversationId)
      .then(resp => {
        const msgs: ChatMessage[] = resp.data
          .map((item: HistoryMessageItem) => this.historyItemToMessage(item))
          .filter((m): m is ChatMessage => m !== null);
        this.messages = msgs;
        this.rerender();
        this.scrollToBottom();
      })
      .catch(() => { /* silently show empty */ });
  }

  private historyItemToMessage(item: HistoryMessageItem): ChatMessage | null {
    switch (item.message_type_id) {
      case 1: case 2: case 11:
        return { id: item.message_id, role: 'user', text: item.query_text ?? item.heard_query_text ?? '', followUps: [], serverMessageId: item.message_id };
      case 3:
        return { id: item.message_id, role: 'assistant', text: item.response_text ?? '', followUps: item.questions ?? [], serverMessageId: item.message_id };
      default: return null;
    }
  }

  // ── Language ───────────────────────────────────────────────────────────────────

  private fetchLanguages(): void {
    if (this.languageGroups.length > 0) return; // already loaded
    this.langLoading = true;
    this.api.getSupportedLanguages()
      .then((groups: SupportedLanguageGroup[]) => {
        this.languageGroups = groups;
        this.langLoading = false;
        if (this.screen === 'profile' || this.screen === 'onboarding') this.rerender();
      })
      .catch(() => { this.langLoading = false; });
  }

  // ── New conversation ───────────────────────────────────────────────────────────

  startNewConversation(): void {
    this.abortStream?.();
    this.messages = [];
    this.conversationId = null;
    this.isStreaming = false;
    this.streamingId = null;
    this.lastError = null;
    this.screen = 'chat';
    this.rerender();
  }

  // ── Utils ──────────────────────────────────────────────────────────────────────

  private scrollToBottom(): void {
    const el = this.root.getElementById('fc-messages');
    if (el) el.scrollTop = el.scrollHeight;
  }

  private rerender(): void {
    const title = this.config.headerTitle ?? 'FarmerChat AI';
    const panelHidden = this.isOpen ? '' : 'fc-hidden';

    // Replace only the panel content to avoid re-creating the shadow root
    const panel = this.root.getElementById('fc-panel');
    if (!panel) { this.render(); this.bindEvents(); return; }

    panel.className = `fc-panel ${panelHidden}`;
    panel.innerHTML = `
      ${this.renderToolbar(title)}
      <div class="fc-screen" id="fc-screen">
        ${this.renderCurrentScreen()}
      </div>`;

    // Update FAB icon
    const fab = this.root.getElementById('fc-fab');
    if (fab) fab.innerHTML = this.isOpen ? ICON.close : ICON.chat;
  }
}
