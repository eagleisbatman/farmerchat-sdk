export const WIDGET_CSS = `
:host { all: initial; }

*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

/* ── Variables ─────────────────────────────────────────────────────────── */
.fc-widget {
  --bg:        #0F1A0D;
  --toolbar:   #1A2318;
  --surface:   #1A2318;
  --surface2:  #243020;
  --card:      #172213;
  --green500:  #4CAF50;
  --green-acc: #69F0AE;
  --text1:     #E8F5E9;
  --text2:     #8FA88C;
  --muted:     #5A6B58;
  --user-bub:  #4CAF50;
  --err-bg:    #3D1C22;
  --err-bdr:   #E57373;
  font-family: system-ui, -apple-system, sans-serif;
  font-size: 14px;
  color: var(--text1);
}

/* ── Panel ─────────────────────────────────────────────────────────────── */
.fc-panel {
  position: fixed;
  bottom: 88px;
  right: 20px;
  width: 380px;
  max-width: calc(100vw - 40px);
  height: 600px;
  max-height: calc(100vh - 110px);
  border-radius: 16px;
  background: var(--bg);
  box-shadow: 0 8px 40px rgba(0,0,0,.55);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  transition: opacity .2s, transform .2s;
  z-index: 2147483646;
}
.fc-panel.fc-hidden { opacity: 0; pointer-events: none; transform: translateY(16px) scale(.97); }

/* ── Toolbar ────────────────────────────────────────────────────────────── */
.fc-toolbar {
  background: var(--toolbar);
  padding: 10px 12px;
  display: flex;
  align-items: center;
  gap: 10px;
  flex-shrink: 0;
  box-shadow: 0 2px 8px rgba(0,0,0,.3);
}
.fc-avatar {
  width: 40px; height: 40px;
  border-radius: 50%;
  background: var(--green500);
  display: flex; align-items: center; justify-content: center;
  font-size: 20px; flex-shrink: 0;
}
.fc-toolbar-info { flex: 1; min-width: 0; }
.fc-toolbar-title {
  font-size: 15px; font-weight: 700; color: var(--text1);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  display: flex; align-items: center; gap: 6px;
}
.fc-online-dot {
  width: 7px; height: 7px; border-radius: 50%;
  background: var(--green-acc); flex-shrink: 0;
}
.fc-toolbar-sub { font-size: 11px; color: var(--text2); margin-top: 1px; }
.fc-icon-btn {
  width: 36px; height: 36px; border-radius: 50%;
  background: transparent; border: none; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  color: var(--text2); transition: background .15s;
  flex-shrink: 0;
}
.fc-icon-btn:hover { background: rgba(255,255,255,.08); }
.fc-icon-btn svg { width: 20px; height: 20px; }

/* ── Screen container ───────────────────────────────────────────────────── */
.fc-screen { flex: 1; display: flex; flex-direction: column; overflow: hidden; }

/* ── Messages ───────────────────────────────────────────────────────────── */
.fc-messages {
  flex: 1; overflow-y: auto; padding: 12px 12px 4px;
  display: flex; flex-direction: column; gap: 12px;
  scroll-behavior: smooth;
}
.fc-messages::-webkit-scrollbar { width: 4px; }
.fc-messages::-webkit-scrollbar-track { background: transparent; }
.fc-messages::-webkit-scrollbar-thumb { background: var(--surface2); border-radius: 4px; }

/* ── Bubbles ────────────────────────────────────────────────────────────── */
.fc-bubble-row { display: flex; gap: 8px; max-width: 100%; }
.fc-bubble-row.user { flex-direction: row-reverse; }
.fc-bot-avatar {
  width: 30px; height: 30px; border-radius: 50%;
  background: var(--green500); display: flex; align-items: center;
  justify-content: center; font-size: 14px; flex-shrink: 0; align-self: flex-end;
}
.fc-bubble {
  max-width: 78%; padding: 10px 12px; border-radius: 14px;
  line-height: 1.5; font-size: 13.5px; word-break: break-word;
}
.fc-bubble.assistant {
  background: var(--surface); border-radius: 14px 14px 14px 4px; color: var(--text1);
}
.fc-bubble.user {
  background: var(--user-bub); border-radius: 14px 14px 4px 14px; color: #fff;
}
.fc-bubble p { margin: 0 0 6px; }
.fc-bubble p:last-child { margin-bottom: 0; }
.fc-bubble ul, .fc-bubble ol { padding-left: 18px; margin: 4px 0; }
.fc-bubble li { margin: 2px 0; }
.fc-bubble strong { font-weight: 600; }
.fc-bubble em { font-style: italic; }
.fc-bubble code {
  background: rgba(255,255,255,.1); border-radius: 4px;
  padding: 1px 5px; font-family: monospace; font-size: 12.5px;
}
.fc-bubble pre { background: rgba(0,0,0,.3); border-radius: 8px; padding: 8px 10px; overflow-x: auto; }
.fc-bubble pre code { background: none; padding: 0; }

/* ── Follow-up chips ────────────────────────────────────────────────────── */
.fc-followups {
  display: flex; flex-direction: column; gap: 6px; margin-top: 8px;
}
.fc-chip {
  display: inline-flex; align-items: center; gap: 6px;
  background: var(--surface2); border: 1px solid var(--muted);
  border-radius: 20px; padding: 6px 12px;
  font-size: 12.5px; color: var(--text1); cursor: pointer;
  text-align: left; transition: background .15s; width: fit-content;
}
.fc-chip:hover { background: var(--green500); border-color: var(--green500); color: #fff; }

/* ── Typing indicator ───────────────────────────────────────────────────── */
.fc-typing { display: flex; gap: 4px; align-items: center; padding: 4px 0; }
.fc-dot {
  width: 7px; height: 7px; border-radius: 50%;
  background: var(--green500); animation: fc-bounce .9s infinite;
}
.fc-dot:nth-child(2) { animation-delay: .15s; }
.fc-dot:nth-child(3) { animation-delay: .3s; }
@keyframes fc-bounce { 0%,80%,100% { transform: translateY(0); } 40% { transform: translateY(-6px); } }

/* ── Error banner ───────────────────────────────────────────────────────── */
.fc-error {
  margin: 8px 12px; padding: 10px 12px; border-radius: 10px;
  background: var(--err-bg); border: 1px solid var(--err-bdr);
  color: #EF9A9A; font-size: 13px; display: flex; align-items: center; gap: 8px;
}
.fc-error button {
  background: var(--err-bdr); border: none; color: #fff; border-radius: 6px;
  padding: 4px 10px; cursor: pointer; font-size: 12px; margin-left: auto;
}

/* ── Empty state ────────────────────────────────────────────────────────── */
.fc-empty {
  flex: 1; display: flex; flex-direction: column;
  align-items: center; justify-content: center; gap: 12px;
  padding: 24px; text-align: center;
}
.fc-empty-emoji { font-size: 48px; }
.fc-empty-title { font-size: 15px; font-weight: 600; color: var(--text1); }
.fc-empty-sub   { font-size: 12.5px; color: var(--text2); line-height: 1.5; }

/* ── Input bar ──────────────────────────────────────────────────────────── */
.fc-input-bar {
  padding: 10px 10px 12px;
  background: var(--toolbar); flex-shrink: 0;
  display: flex; align-items: center; gap: 8px;
}
.fc-input {
  flex: 1; background: var(--surface2); border: none; border-radius: 22px;
  padding: 10px 14px; color: var(--text1); font-size: 13.5px; outline: none;
  resize: none; max-height: 100px; overflow-y: auto; line-height: 1.4;
  font-family: inherit;
}
.fc-input::placeholder { color: var(--muted); }
.fc-send-btn {
  width: 40px; height: 40px; border-radius: 50%; background: var(--green500);
  border: none; cursor: pointer; display: flex; align-items: center; justify-content: center;
  flex-shrink: 0; transition: opacity .15s;
}
.fc-send-btn:disabled { opacity: .4; cursor: default; }
.fc-send-btn svg { width: 18px; height: 18px; color: #fff; }

/* ── History screen ─────────────────────────────────────────────────────── */
.fc-list-header {
  padding: 8px 12px;
  display: flex; flex-direction: column; gap: 6px;
  background: var(--toolbar); flex-shrink: 0;
}
.fc-search {
  background: var(--surface2); border: none; border-radius: 10px;
  padding: 8px 12px 8px 32px; color: var(--text1); font-size: 13px;
  outline: none; width: 100%; font-family: inherit;
  background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='%235A6B58' viewBox='0 0 24 24'%3E%3Cpath d='M21 21l-4.35-4.35M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16z' stroke='%235A6B58' stroke-width='2' fill='none'/%3E%3C/svg%3E");
  background-repeat: no-repeat;
  background-position: 10px center;
}
.fc-search::placeholder { color: var(--muted); }
.fc-conv-list {
  flex: 1; overflow-y: auto; padding: 8px;
  display: flex; flex-direction: column; gap: 6px;
}
.fc-conv-list::-webkit-scrollbar { width: 4px; }
.fc-conv-list::-webkit-scrollbar-thumb { background: var(--surface2); border-radius: 4px; }
.fc-conv-item {
  background: var(--card); border-radius: 12px; padding: 12px 14px;
  cursor: pointer; transition: background .15s;
  display: flex; align-items: center; gap: 10px;
}
.fc-conv-item:hover { background: var(--surface2); }
.fc-conv-icon {
  width: 40px; height: 40px; border-radius: 50%; background: var(--surface2);
  display: flex; align-items: center; justify-content: center; font-size: 18px; flex-shrink: 0;
}
.fc-conv-info { flex: 1; min-width: 0; }
.fc-conv-title {
  font-size: 13.5px; font-weight: 600; color: var(--text1);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.fc-conv-date { font-size: 11.5px; color: var(--text2); margin-top: 2px; }
.fc-conv-arrow { color: var(--text2); font-size: 18px; flex-shrink: 0; }
.fc-section-label {
  padding: 4px 10px 2px; font-size: 11px; font-weight: 700;
  color: var(--green500); letter-spacing: .8px; text-transform: uppercase;
}

/* ── Profile/Language screen ────────────────────────────────────────────── */
.fc-lang-list {
  flex: 1; overflow-y: auto; padding: 8px;
  display: flex; flex-direction: column; gap: 6px;
}
.fc-lang-list::-webkit-scrollbar { width: 4px; }
.fc-lang-list::-webkit-scrollbar-thumb { background: var(--surface2); border-radius: 4px; }
.fc-lang-item {
  background: var(--surface); border: 1.5px solid var(--surface2);
  border-radius: 12px; padding: 12px 14px; cursor: pointer;
  display: flex; align-items: center; gap: 10px; transition: background .15s;
}
.fc-lang-item:hover { background: var(--surface2); }
.fc-lang-item.selected { background: rgba(76,175,80,.1); border-color: var(--green500); }
.fc-lang-names { flex: 1; min-width: 0; }
.fc-lang-native { font-size: 14px; font-weight: 600; color: var(--text1); }
.fc-lang-en { font-size: 12px; color: var(--text2); margin-top: 2px; }
.fc-check {
  width: 20px; height: 20px; border-radius: 50%;
  background: var(--green500); display: flex; align-items: center;
  justify-content: center; flex-shrink: 0;
}
.fc-check svg { width: 12px; height: 12px; color: #fff; }
.fc-profile-footer {
  padding: 10px; text-align: center; font-size: 11px; color: var(--muted);
  border-top: 1px solid var(--surface2); flex-shrink: 0;
}

/* ── Onboarding ─────────────────────────────────────────────────────────── */
.fc-onboard {
  flex: 1; display: flex; flex-direction: column;
  padding: 20px 16px 12px; overflow-y: auto;
}
.fc-onboard-hero { text-align: center; margin-bottom: 20px; }
.fc-onboard-emoji { font-size: 40px; }
.fc-onboard-title { font-size: 16px; font-weight: 700; color: var(--text1); margin-top: 8px; }
.fc-onboard-sub   { font-size: 12.5px; color: var(--text2); margin-top: 4px; line-height: 1.5; }
.fc-onboard-lang-list {
  flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 6px; margin-bottom: 12px;
}
.fc-onboard-lang-list::-webkit-scrollbar { width: 4px; }
.fc-onboard-lang-list::-webkit-scrollbar-thumb { background: var(--surface2); border-radius: 4px; }
.fc-start-btn {
  width: 100%; padding: 12px; border-radius: 22px;
  background: var(--green500); border: none; color: #fff;
  font-size: 14px; font-weight: 700; cursor: pointer; transition: opacity .15s;
  flex-shrink: 0;
}
.fc-start-btn:disabled { opacity: .4; cursor: default; }

/* ── Loading spinner ────────────────────────────────────────────────────── */
.fc-spinner-wrap {
  flex: 1; display: flex; align-items: center; justify-content: center;
}
.fc-spinner {
  width: 28px; height: 28px; border-radius: 50%;
  border: 3px solid var(--surface2); border-top-color: var(--green500);
  animation: fc-spin .7s linear infinite;
}
@keyframes fc-spin { to { transform: rotate(360deg); } }

/* ── FAB ────────────────────────────────────────────────────────────────── */
.fc-fab {
  position: fixed; bottom: 20px; right: 20px;
  width: 56px; height: 56px; border-radius: 50%;
  background: var(--green500); border: none; cursor: pointer;
  box-shadow: 0 4px 16px rgba(76,175,80,.5);
  display: flex; align-items: center; justify-content: center;
  z-index: 2147483647; transition: transform .2s, box-shadow .2s;
  color: #fff;
}
.fc-fab:hover { transform: scale(1.07); box-shadow: 0 6px 20px rgba(76,175,80,.6); }
.fc-fab svg { width: 26px; height: 26px; }
.fc-fab-badge {
  position: absolute; top: 6px; right: 6px;
  width: 10px; height: 10px; border-radius: 50%;
  background: #ff5252; border: 2px solid var(--green500);
  display: none;
}
.fc-fab-badge.show { display: block; }

/* ── Connectivity banner ────────────────────────────────────────────────── */
.fc-connectivity {
  padding: 6px 12px; background: #2C1A00;
  color: #FFB74D; font-size: 12px; text-align: center; flex-shrink: 0;
}
`;
