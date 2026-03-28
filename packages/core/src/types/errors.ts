import { ErrorCodes } from '../constants/error-codes';

/** All possible FarmerChat error codes */
export type FarmerChatErrorCode = (typeof ErrorCodes)[keyof typeof ErrorCodes];

/**
 * Custom error class for all SDK errors.
 */
export class FarmerChatError extends Error {
  /** Machine-readable error code */
  readonly code: FarmerChatErrorCode;

  /** Whether this error is fatal (requires SDK restart) */
  readonly fatal: boolean;

  /** Retryable error — transient, can be retried */
  readonly retryable: boolean;

  /** HTTP status code if applicable */
  readonly httpStatus?: number;

  constructor(
    code: FarmerChatErrorCode,
    message: string,
    options?: { fatal?: boolean; retryable?: boolean; httpStatus?: number; cause?: Error }
  ) {
    super(message, { cause: options?.cause });
    this.name = 'FarmerChatError';
    this.code = code;
    this.fatal = options?.fatal ?? false;
    this.retryable = options?.retryable ?? false;
    this.httpStatus = options?.httpStatus;
  }
}
