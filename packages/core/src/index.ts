// Types
export type {
  FarmerChatConfig,
  ThemeConfig,
  CrashConfig,
  CrashReporter,
} from './types/config';

export type {
  SDKEvent,
  OnChatOpened,
  OnChatClosed,
  OnQuerySent,
  OnResponseReceived,
  OnError,
  OnStreamingStarted,
  OnStreamingToken,
  OnFeedbackSubmitted,
  OnLanguageChanged,
  OnOnboardingCompleted,
  OnConnectivityChanged,
  EventCallback,
} from './types/events';

export type {
  Query,
  Response,
  StreamToken,
  FollowUpQuestion,
  StarterQuestion,
  ResponseSource,
  FeedbackPayload,
  Message,
  Conversation,
  Language,
  OnboardingPayload,
} from './types/messages';

export {
  FarmerChatError,
  type FarmerChatErrorCode,
} from './types/errors';

// Markdown
export { parse as parseMarkdown, parseInline, StreamingMarkdownParser } from './markdown';
export type {
  MarkdownDocument,
  MarkdownNode,
  BlockNode,
  InlineNode,
  TextNode,
  BoldNode,
  ItalicNode,
  StrikethroughNode,
  LinkNode,
  LineBreakNode,
  ParagraphNode,
  HeadingNode,
  BulletListNode,
  OrderedListNode,
  ListItemNode,
  TaskListNode,
  TaskItemNode,
  TableNode,
  TableRowNode,
  TableCellNode,
  TableAlignment,
  ImageNode,
  HorizontalRuleNode,
} from './markdown';

// API
export { FarmerChatApiClient } from './api/client';
export { SSEParser, type SSEEvent } from './api/sse-parser';
export { withRetry, type RetryConfig } from './api/retry';
export { Endpoints } from './api/endpoints';

// Constants
export { DEFAULTS } from './constants/defaults';
export { ErrorCodes } from './constants/error-codes';
