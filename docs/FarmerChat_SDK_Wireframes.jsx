import { useState } from "react";

const SCREENS = {
  fab: "FAB Overlay",
  onboard_location: "Onboarding: Location",
  onboard_language: "Onboarding: Language",
  chat_empty: "Chat: Empty (Starters)",
  chat_active: "Chat: Active Conversation",
  chat_streaming: "Chat: Streaming Response",
  chat_offline: "Chat: Connectivity Lost",
  history: "History",
  profile: "Profile",
  dx_portal: "DX: Developer Portal",
  dx_init: "DX: SDK Initialization",
  dx_config: "DX: Configuration",
};

const UX_SCREENS = ["fab", "onboard_location", "onboard_language", "chat_empty", "chat_active", "chat_streaming", "chat_offline", "history", "profile"];
const DX_SCREENS = ["dx_portal", "dx_init", "dx_config"];

function PhoneFrame({ children }) {
  return (
    <div style={{ width: 320, minHeight: 580, background: "#fff", borderRadius: 32, border: "3px solid #1a1a1a", overflow: "hidden", display: "flex", flexDirection: "column", boxShadow: "0 8px 32px rgba(0,0,0,0.18)" }}>
      <div style={{ height: 32, background: "#1a1a1a", display: "flex", alignItems: "center", justifyContent: "center" }}>
        <div style={{ width: 80, height: 6, background: "#333", borderRadius: 3 }} />
      </div>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", position: "relative" }}>{children}</div>
      <div style={{ height: 20, background: "#f5f5f5", display: "flex", alignItems: "center", justifyContent: "center" }}>
        <div style={{ width: 100, height: 4, background: "#ccc", borderRadius: 2 }} />
      </div>
    </div>
  );
}

function ChatHeader() {
  return (
    <div style={{ display: "flex", alignItems: "center", padding: "10px 14px", background: "#1B6B3A", color: "#fff", gap: 10 }}>
      <div style={{ width: 28, height: 28, borderRadius: 14, background: "rgba(255,255,255,0.2)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 14, fontWeight: 700 }}>FC</div>
      <span style={{ flex: 1, fontWeight: 600, fontSize: 15 }}>Krishi Mitra</span>
      <div style={{ display: "flex", gap: 14, fontSize: 14, opacity: 0.8 }}>
        <span>🌐</span><span>☰</span><span>👤</span><span>✕</span>
      </div>
    </div>
  );
}

function InputBar({ disabled = false }) {
  return (
    <div style={{ padding: "8px 12px", background: "#f8f8f8", borderTop: "1px solid #e5e5e5", display: "flex", alignItems: "center", gap: 8 }}>
      <div style={{ flex: 1, background: disabled ? "#eee" : "#fff", border: "1px solid #ddd", borderRadius: 20, padding: "8px 14px", fontSize: 13, color: disabled ? "#aaa" : "#999" }}>
        {disabled ? "No connection..." : "Ask about your crops..."}
      </div>
      <div style={{ display: "flex", gap: 6 }}>
        <div style={{ width: 32, height: 32, borderRadius: 16, background: disabled ? "#ddd" : "#f0f0f0", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 14 }}>📷</div>
        <div style={{ width: 32, height: 32, borderRadius: 16, background: disabled ? "#ddd" : "#f0f0f0", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 14 }}>🎤</div>
        <div style={{ width: 32, height: 32, borderRadius: 16, background: disabled ? "#ccc" : "#1B6B3A", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 14, color: "#fff" }}>➤</div>
      </div>
    </div>
  );
}

function ResponseCard({ text, showActions = true, streaming = false }) {
  return (
    <div style={{ padding: "0 14px", marginBottom: 12 }}>
      <div style={{ display: "flex", gap: 8, marginBottom: 6 }}>
        <div style={{ width: 22, height: 22, borderRadius: 11, background: "#1B6B3A", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 9, color: "#fff", fontWeight: 700, flexShrink: 0, marginTop: 2 }}>FC</div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 12.5, lineHeight: 1.6, color: "#1a1a1a", whiteSpace: "pre-wrap" }}>
            {text}{streaming && <span style={{ display: "inline-block", width: 8, height: 14, background: "#1B6B3A", marginLeft: 2, borderRadius: 1 }} className="blink" />}
          </div>
          {showActions && !streaming && (
            <>
              <div style={{ display: "flex", gap: 6, marginTop: 8, flexWrap: "wrap" }}>
                {["How often to water?", "Best fertilizer?"].map(q => (
                  <div key={q} style={{ fontSize: 11, background: "#f0f7f2", border: "1px solid #c8e0cf", borderRadius: 14, padding: "5px 10px", color: "#1B6B3A" }}>{q}</div>
                ))}
              </div>
              <div style={{ display: "flex", gap: 12, marginTop: 8, fontSize: 14 }}>
                <span>👍</span><span>👎</span><span>🔊</span><span>↗</span><span>📋</span>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

function UserQuery({ text }) {
  return (
    <div style={{ padding: "0 14px", marginBottom: 12 }}>
      <div style={{ fontSize: 12.5, lineHeight: 1.6, color: "#1a1a1a", background: "#f5f5f5", padding: "10px 14px", borderRadius: 12 }}>{text}</div>
    </div>
  );
}

function FabScreen() {
  return (
    <PhoneFrame>
      <div style={{ flex: 1, background: "#f5f5f5", padding: 16 }}>
        <div style={{ background: "#fff", borderRadius: 12, padding: 14, marginBottom: 10, boxShadow: "0 1px 3px rgba(0,0,0,0.08)" }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: "#333", marginBottom: 6 }}>Partner App Screen</div>
          <div style={{ fontSize: 12, color: "#888", lineHeight: 1.5 }}>The FarmerChat FAB floats above partner content. Tapping opens the chat widget.</div>
        </div>
        <div style={{ background: "#fff", borderRadius: 12, padding: 14, boxShadow: "0 1px 3px rgba(0,0,0,0.08)" }}>
          {[80, 60, 70].map((w, i) => <div key={i} style={{ height: 8, background: "#eee", borderRadius: 4, marginBottom: 8, width: `${w}%` }} />)}
        </div>
      </div>
      <div style={{ position: "absolute", bottom: 40, right: 20, width: 56, height: 56, borderRadius: 28, background: "#1B6B3A", display: "flex", alignItems: "center", justifyContent: "center", boxShadow: "0 4px 12px rgba(27,107,58,0.4)", cursor: "pointer", color: "#fff", fontWeight: 700, fontSize: 16 }}>FC</div>
      <div style={{ position: "absolute", bottom: 100, right: 16, background: "#333", color: "#fff", fontSize: 10, padding: "4px 8px", borderRadius: 4 }}>Tap to open chat</div>
    </PhoneFrame>
  );
}

function OnboardLocationScreen() {
  return (
    <PhoneFrame>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: 24, background: "#fff" }}>
        <div style={{ width: 72, height: 72, borderRadius: 36, background: "#f0f7f2", display: "flex", alignItems: "center", justifyContent: "center", marginBottom: 20, fontSize: 32 }}>📍</div>
        <div style={{ fontSize: 18, fontWeight: 700, color: "#1a1a1a", marginBottom: 8 }}>Share Your Location</div>
        <div style={{ fontSize: 13, color: "#666", textAlign: "center", lineHeight: 1.6, marginBottom: 28, maxWidth: 240 }}>To give you advice specific to your area's weather, soil, and crops.</div>
        <div style={{ width: "100%", background: "#1B6B3A", color: "#fff", padding: "12px 0", borderRadius: 12, textAlign: "center", fontSize: 14, fontWeight: 600, marginBottom: 12 }}>Allow Location Access</div>
        <div style={{ fontSize: 12, color: "#1B6B3A", textDecoration: "underline" }}>Enter location manually</div>
      </div>
      <div style={{ padding: "10px 16px", background: "#f8f8f8", textAlign: "center", fontSize: 10, color: "#999" }}>Step 1 of 2</div>
    </PhoneFrame>
  );
}

function OnboardLanguageScreen() {
  const langs = [{ n: "English", v: "English", s: false }, { n: "Hindi", v: "हिन्दी", s: true }, { n: "Marathi", v: "मराठी", s: false }, { n: "Telugu", v: "తెలుగు", s: false }, { n: "Swahili", v: "Kiswahili", s: false }, { n: "French", v: "Français", s: false }];
  return (
    <PhoneFrame>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: 24, background: "#fff" }}>
        <div style={{ fontSize: 18, fontWeight: 700, marginBottom: 4 }}>Choose Language</div>
        <div style={{ fontSize: 13, color: "#666", marginBottom: 20 }}>Select your preferred language</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10, flex: 1 }}>
          {langs.map(l => (
            <div key={l.n} style={{ border: l.s ? "2px solid #1B6B3A" : "1px solid #ddd", borderRadius: 12, padding: "14px 12px", textAlign: "center", background: l.s ? "#f0f7f2" : "#fff" }}>
              <div style={{ fontSize: 18, marginBottom: 4 }}>{l.v}</div>
              <div style={{ fontSize: 11, color: "#888" }}>{l.n}</div>
              {l.s && <div style={{ color: "#1B6B3A", marginTop: 4, fontSize: 14 }}>✓</div>}
            </div>
          ))}
        </div>
        <div style={{ width: "100%", background: "#1B6B3A", color: "#fff", padding: "12px 0", borderRadius: 12, textAlign: "center", fontSize: 14, fontWeight: 600, marginTop: 16 }}>Continue</div>
      </div>
      <div style={{ padding: "10px 16px", background: "#f8f8f8", textAlign: "center", fontSize: 10, color: "#999" }}>Step 2 of 2</div>
    </PhoneFrame>
  );
}

function ChatEmptyScreen() {
  return (
    <PhoneFrame>
      <ChatHeader />
      <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "16px 0", background: "#fff" }}>
        <div style={{ textAlign: "center", padding: "20px 14px 10px", fontSize: 14, color: "#666" }}>How can I help you today?</div>
        <div style={{ padding: "0 14px", display: "flex", flexDirection: "column", gap: 8, marginTop: 8 }}>
          {["What crops are best this season in my area?", "How to treat yellowing leaves on tomatoes?", "Current market price for wheat?", "How to prepare soil for next season?"].map(q => (
            <div key={q} style={{ background: "#f0f7f2", border: "1px solid #c8e0cf", borderRadius: 12, padding: "10px 14px", fontSize: 12, color: "#1B6B3A" }}>{q}</div>
          ))}
        </div>
      </div>
      <InputBar />
    </PhoneFrame>
  );
}

function ChatActiveScreen() {
  return (
    <PhoneFrame>
      <ChatHeader />
      <div style={{ flex: 1, overflow: "auto", padding: "12px 0", background: "#fff" }}>
        <UserQuery text="How do I treat yellowing leaves on my tomato plants?" />
        <ResponseCard text={"Yellowing leaves can be caused by:\n\n• Nitrogen Deficiency — Apply balanced fertilizer (10-10-10) at the base.\n• Overwatering — Ensure soil drains well.\n• Early Blight — Remove affected leaves, apply copper fungicide."} />
        <UserQuery text="Which fertilizer should I use?" />
        <ResponseCard text={"For nitrogen deficiency:\n\n• Urea (46-0-0) — 20g per plant, mix into soil.\n• Organic: Neem cake (5:1:1) at 100g per plant."} />
      </div>
      <InputBar />
    </PhoneFrame>
  );
}

function ChatStreamingScreen() {
  return (
    <PhoneFrame>
      <ChatHeader />
      <div style={{ flex: 1, overflow: "auto", padding: "12px 0", background: "#fff" }}>
        <UserQuery text="What pests affect maize in central Kenya?" />
        <ResponseCard text={"The most common pests affecting maize in central Kenya:\n\nFall Armyworm (FAW) — The biggest threat. Look for..."} streaming={true} showActions={false} />
        <div style={{ padding: "0 14px", fontSize: 11, color: "#999", display: "flex", alignItems: "center", gap: 6 }}>
          <div style={{ width: 6, height: 6, borderRadius: 3, background: "#1B6B3A" }} className="pulse" />
          Generating response...
          <span style={{ marginLeft: "auto", color: "#1B6B3A", cursor: "pointer" }}>Stop</span>
        </div>
      </div>
      <InputBar />
    </PhoneFrame>
  );
}

function ChatOfflineScreen() {
  return (
    <PhoneFrame>
      <ChatHeader />
      <div style={{ background: "#FFF3CD", padding: "8px 14px", display: "flex", alignItems: "center", gap: 8, fontSize: 12, color: "#856404" }}>
        📶 <span style={{ flex: 1 }}>You're offline. Reconnecting...</span>
        <span style={{ textDecoration: "underline", cursor: "pointer" }}>Retry</span>
      </div>
      <div style={{ flex: 1, overflow: "auto", padding: "12px 0", background: "#fff" }}>
        <UserQuery text="How do I treat yellowing leaves?" />
        <ResponseCard text="Yellowing leaves can be caused by nitrogen deficiency..." />
        <UserQuery text="What about organic options?" />
        <div style={{ padding: "0 14px" }}>
          <div style={{ background: "#FFF3CD", borderRadius: 10, padding: "12px 14px", fontSize: 12, color: "#856404", textAlign: "center" }}>
            <div style={{ marginBottom: 6 }}>Failed to send. Check your connection.</div>
            <span style={{ background: "#856404", color: "#fff", padding: "4px 14px", borderRadius: 6, fontSize: 11 }}>Tap to Retry</span>
          </div>
        </div>
      </div>
      <InputBar disabled={true} />
    </PhoneFrame>
  );
}

function HistoryScreen() {
  const chats = [
    { t: "Tomato yellowing leaves", d: "Today, 2:30 PM", p: "Apply nitrogen fertilizer..." },
    { t: "Maize planting season", d: "Yesterday", p: "Best time to plant in central..." },
    { t: "Wheat market prices", d: "Mar 22", p: "Current wheat prices in Mandi..." },
    { t: "Soil preparation tips", d: "Mar 20", p: "For red soil, add organic matter..." },
  ];
  return (
    <PhoneFrame>
      <div style={{ display: "flex", alignItems: "center", padding: "10px 14px", background: "#1B6B3A", color: "#fff", gap: 10 }}>
        <span>←</span><span style={{ flex: 1, fontWeight: 600, fontSize: 15 }}>Chat History</span>
      </div>
      <div style={{ flex: 1, background: "#fff" }}>
        {chats.map((c, i) => (
          <div key={i} style={{ padding: "12px 14px", borderBottom: "1px solid #f0f0f0" }}>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
              <span style={{ fontSize: 13, fontWeight: 600 }}>{c.t}</span>
              <span style={{ fontSize: 10, color: "#999" }}>{c.d}</span>
            </div>
            <div style={{ fontSize: 12, color: "#888", overflow: "hidden", whiteSpace: "nowrap", textOverflow: "ellipsis" }}>{c.p}</div>
          </div>
        ))}
      </div>
    </PhoneFrame>
  );
}

function ProfileScreen() {
  return (
    <PhoneFrame>
      <div style={{ display: "flex", alignItems: "center", padding: "10px 14px", background: "#1B6B3A", color: "#fff", gap: 10 }}>
        <span>←</span><span style={{ flex: 1, fontWeight: 600, fontSize: 15 }}>Profile & Settings</span>
      </div>
      <div style={{ flex: 1, background: "#fff", padding: "16px 14px" }}>
        <div style={{ textAlign: "center", marginBottom: 20 }}>
          <div style={{ width: 56, height: 56, borderRadius: 28, background: "#f0f7f2", display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 8px", fontSize: 22 }}>👤</div>
          <div style={{ fontSize: 14, fontWeight: 600 }}>Farmer User</div>
        </div>
        {[{ l: "Language", v: "हिन्दी (Hindi)" }, { l: "Location", v: "Pune, Maharashtra" }, { l: "Crops", v: "Tomato, Wheat, Rice" }].map((it, i) => (
          <div key={i} style={{ display: "flex", alignItems: "center", padding: "12px 0", borderBottom: "1px solid #f0f0f0" }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 11, color: "#888" }}>{it.l}</div>
              <div style={{ fontSize: 13 }}>{it.v}</div>
            </div>
            <span style={{ color: "#ccc" }}>›</span>
          </div>
        ))}
        <div style={{ marginTop: 20, color: "#cc0000", fontSize: 13 }}>🗑 Clear Chat History</div>
        <div style={{ marginTop: 30, textAlign: "center", fontSize: 10, color: "#ccc" }}>Powered by FarmerChat v1.0.0</div>
      </div>
    </PhoneFrame>
  );
}

function DxPortalScreen() {
  return (
    <div style={{ width: 520, background: "#fff", borderRadius: 12, border: "1px solid #e5e5e5", overflow: "hidden", boxShadow: "0 4px 16px rgba(0,0,0,0.08)" }}>
      <div style={{ background: "#1B6B3A", padding: "16px 20px", color: "#fff" }}>
        <div style={{ fontSize: 18, fontWeight: 700 }}>FarmerChat Developer Portal</div>
        <div style={{ fontSize: 12, opacity: 0.8, marginTop: 4 }}>Manage API keys, view usage, configure SDKs</div>
      </div>
      <div style={{ padding: 20 }}>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12, marginBottom: 20 }}>
          {[{ l: "API Key", v: "fc_pub_a1b2...z0" }, { l: "Environment", v: "Sandbox" }, { l: "Queries Today", v: "1,247" }, { l: "Active Users", v: "8,932" }].map((c, i) => (
            <div key={i} style={{ background: "#f8f8f8", borderRadius: 8, padding: 12 }}>
              <div style={{ fontSize: 10, color: "#888", marginBottom: 4, textTransform: "uppercase" }}>{c.l}</div>
              <div style={{ fontSize: 14, fontWeight: 600 }}>{c.v}</div>
            </div>
          ))}
        </div>
        <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 8 }}>Quick Start</div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          {["Android Compose", "Android XML", "iOS SwiftUI", "iOS UIKit", "React Native"].map(p => (
            <div key={p} style={{ fontSize: 11, padding: "6px 12px", background: "#f0f7f2", border: "1px solid #c8e0cf", borderRadius: 6, color: "#1B6B3A" }}>{p}</div>
          ))}
        </div>
      </div>
    </div>
  );
}

function DxInitScreen() {
  return (
    <div style={{ width: 520, background: "#1a1a1a", borderRadius: 12, overflow: "hidden", boxShadow: "0 4px 16px rgba(0,0,0,0.2)", fontFamily: "'Courier New', monospace" }}>
      <div style={{ display: "flex", alignItems: "center", padding: "8px 12px", background: "#2a2a2a", gap: 6 }}>
        <div style={{ width: 10, height: 10, borderRadius: 5, background: "#ff5f57" }} />
        <div style={{ width: 10, height: 10, borderRadius: 5, background: "#ffbd2e" }} />
        <div style={{ width: 10, height: 10, borderRadius: 5, background: "#28ca42" }} />
        <span style={{ fontSize: 11, color: "#888", marginLeft: 8 }}>Application.kt</span>
      </div>
      <div style={{ padding: "16px 20px", fontSize: 12, lineHeight: 1.8, color: "#ccc" }}>
        <div><span style={{ color: "#569CD6" }}>dependencies</span> {"{"}</div>
        <div style={{ paddingLeft: 16 }}><span style={{ color: "#888" }}>// One line to add FarmerChat</span></div>
        <div style={{ paddingLeft: 16 }}><span style={{ color: "#DCDCAA" }}>implementation</span><span style={{ color: "#CE9178" }}>("org.digitalgreen:farmerchat:1.0.0")</span></div>
        <div>{"}"}</div>
        <div style={{ marginTop: 12 }}><span style={{ color: "#569CD6" }}>class</span> <span style={{ color: "#4EC9B0" }}>App</span> : <span style={{ color: "#4EC9B0" }}>Application</span>() {"{"}</div>
        <div style={{ paddingLeft: 16 }}><span style={{ color: "#569CD6" }}>override fun</span> <span style={{ color: "#DCDCAA" }}>onCreate</span>() {"{"}</div>
        <div style={{ paddingLeft: 32 }}><span style={{ color: "#4EC9B0" }}>FarmerChat</span>.<span style={{ color: "#DCDCAA" }}>initialize</span>(</div>
        <div style={{ paddingLeft: 48 }}><span style={{ color: "#9CDCFE" }}>apiKey</span> = <span style={{ color: "#CE9178" }}>"fc_pub_xxx"</span>,</div>
        <div style={{ paddingLeft: 48 }}><span style={{ color: "#9CDCFE" }}>config</span> = <span style={{ color: "#4EC9B0" }}>FarmerChatConfig</span>(</div>
        <div style={{ paddingLeft: 64 }}><span style={{ color: "#9CDCFE" }}>primaryColor</span> = <span style={{ color: "#B5CEA8" }}>0xFF1B6B3A</span></div>
        <div style={{ paddingLeft: 48 }}>)</div>
        <div style={{ paddingLeft: 32 }}>)</div>
        <div style={{ paddingLeft: 16 }}>{"}"}</div>
        <div>{"}"}</div>
        <div style={{ marginTop: 12, color: "#6A9955" }}>// 10 lines. That's the full integration.</div>
      </div>
    </div>
  );
}

function DxConfigScreen() {
  const fields = [
    { l: "Header Title", v: "Krishi Mitra", t: "text" },
    { l: "Primary Color", v: "#1B6B3A", t: "color" },
    { l: "Default Language", v: "Hindi (hi)", t: "text" },
    { l: "Voice Input", v: true, t: "toggle" },
    { l: "Image Input", v: true, t: "toggle" },
    { l: "Chat History", v: true, t: "toggle" },
    { l: "Profile Section", v: false, t: "toggle" },
    { l: "Crash Provider", v: "Firebase", t: "text" },
    { l: "Powered By", v: true, t: "toggle" },
  ];
  return (
    <div style={{ width: 520, background: "#fff", borderRadius: 12, border: "1px solid #e5e5e5", overflow: "hidden", boxShadow: "0 4px 16px rgba(0,0,0,0.08)" }}>
      <div style={{ background: "#f8f8f8", padding: "12px 20px", borderBottom: "1px solid #e5e5e5" }}>
        <div style={{ fontSize: 14, fontWeight: 700 }}>SDK Configuration Builder</div>
        <div style={{ fontSize: 11, color: "#888" }}>Customize your FarmerChat widget</div>
      </div>
      <div style={{ padding: 20, display: "flex", flexDirection: "column", gap: 14 }}>
        {fields.map((f, i) => (
          <div key={i} style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div style={{ width: 140, fontSize: 12, color: "#666" }}>{f.l}</div>
            <div style={{ flex: 1 }}>
              {f.t === "color" ? (
                <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                  <div style={{ width: 24, height: 24, borderRadius: 6, background: f.v, border: "1px solid #ddd" }} />
                  <span style={{ fontSize: 12, fontFamily: "monospace" }}>{f.v}</span>
                </div>
              ) : f.t === "toggle" ? (
                <div style={{ width: 36, height: 20, borderRadius: 10, background: f.v ? "#1B6B3A" : "#ccc", position: "relative" }}>
                  <div style={{ width: 16, height: 16, borderRadius: 8, background: "#fff", position: "absolute", top: 2, left: f.v ? 18 : 2 }} />
                </div>
              ) : (
                <div style={{ fontSize: 12, padding: "4px 8px", background: "#f5f5f5", borderRadius: 4, border: "1px solid #ddd" }}>{f.v}</div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

const R = { fab: FabScreen, onboard_location: OnboardLocationScreen, onboard_language: OnboardLanguageScreen, chat_empty: ChatEmptyScreen, chat_active: ChatActiveScreen, chat_streaming: ChatStreamingScreen, chat_offline: ChatOfflineScreen, history: HistoryScreen, profile: ProfileScreen, dx_portal: DxPortalScreen, dx_init: DxInitScreen, dx_config: DxConfigScreen };

export default function App() {
  const [screen, setScreen] = useState("fab");
  const [mode, setMode] = useState("ux");
  const screens = mode === "ux" ? UX_SCREENS : DX_SCREENS;
  const Comp = R[screen];

  return (
    <div style={{ minHeight: "100vh", background: "#f0f0f0", fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif" }}>
      <style>{`
        .blink { animation: blink 1s infinite }
        .pulse { animation: pulse 1.5s infinite }
        @keyframes blink { 0%,50%{opacity:1}51%,100%{opacity:0} }
        @keyframes pulse { 0%,100%{opacity:1}50%{opacity:0.4} }
      `}</style>
      <div style={{ padding: "16px 20px", background: "#1a1a1a", color: "#fff", display: "flex", alignItems: "center", gap: 16 }}>
        <div style={{ fontSize: 16, fontWeight: 700 }}>FarmerChat SDK Wireframes</div>
        <div style={{ display: "flex", gap: 4, marginLeft: "auto", background: "#333", borderRadius: 6, padding: 2 }}>
          {["ux", "dx"].map(m => (
            <button key={m} onClick={() => { setMode(m); setScreen(m === "ux" ? "fab" : "dx_portal"); }} style={{ padding: "6px 14px", borderRadius: 4, border: "none", background: mode === m ? "#1B6B3A" : "transparent", color: mode === m ? "#fff" : "#aaa", fontSize: 12, fontWeight: 600, cursor: "pointer" }}>
              {m === "ux" ? "End User UX" : "Developer DX"}
            </button>
          ))}
        </div>
      </div>
      <div style={{ display: "flex", gap: 4, padding: "12px 20px", overflowX: "auto", background: "#e8e8e8" }}>
        {screens.map(k => (
          <button key={k} onClick={() => setScreen(k)} style={{ padding: "6px 12px", borderRadius: 6, border: screen === k ? "2px solid #1B6B3A" : "1px solid #ccc", background: screen === k ? "#f0f7f2" : "#fff", color: screen === k ? "#1B6B3A" : "#666", fontSize: 11, fontWeight: screen === k ? 600 : 400, cursor: "pointer", whiteSpace: "nowrap", flexShrink: 0 }}>
            {SCREENS[k]}
          </button>
        ))}
      </div>
      <div style={{ display: "flex", justifyContent: "center", padding: "24px 20px", minHeight: 640 }}>
        {Comp && <Comp />}
      </div>
      <div style={{ padding: "12px 20px", background: "#e8e8e8", fontSize: 11, color: "#888", textAlign: "center" }}>
        {mode === "ux" ? "End User flow: FAB → Onboarding → Chat → History → Profile" : "Developer flow: Portal → Init Code → Config Builder"}
      </div>
    </div>
  );
}
