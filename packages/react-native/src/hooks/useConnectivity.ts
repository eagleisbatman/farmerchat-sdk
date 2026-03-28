import { useState, useEffect, useRef, useCallback } from 'react';

const CONNECTIVITY_CHECK_URL = 'https://clients3.google.com/generate_204';
const CHECK_INTERVAL_MS = 15_000;
const CHECK_TIMEOUT_MS = 5_000;

/**
 * Network connectivity hook.
 *
 * Monitors internet reachability via periodic HEAD requests.
 * No heavyweight dependencies (no @react-native-community/netinfo) --
 * uses plain fetch which is always available in React Native.
 */
export function useConnectivity() {
  const [isConnected, setIsConnected] = useState(true);
  const intervalRef = useRef<ReturnType<typeof setInterval> | undefined>(undefined);
  const isMountedRef = useRef(true);

  const check = useCallback(async (): Promise<boolean> => {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), CHECK_TIMEOUT_MS);
      await fetch(CONNECTIVITY_CHECK_URL, {
        method: 'HEAD',
        signal: controller.signal,
      });
      clearTimeout(timeout);
      if (isMountedRef.current) setIsConnected(true);
      return true;
    } catch {
      if (isMountedRef.current) setIsConnected(false);
      return false;
    }
  }, []);

  useEffect(() => {
    isMountedRef.current = true;

    // Initial check
    check();

    // Periodic check
    intervalRef.current = setInterval(check, CHECK_INTERVAL_MS);

    return () => {
      isMountedRef.current = false;
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
  }, [check]);

  /**
   * Trigger an immediate connectivity check.
   * Returns the result synchronously (true = connected).
   */
  const checkNow = useCallback(async (): Promise<boolean> => {
    return check();
  }, [check]);

  return { isConnected, checkNow };
}
