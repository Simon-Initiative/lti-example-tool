const REFRESH_TOKEN_KEY = "lti_refresh_token";
const BOOTSTRAP_TOKEN_KEY = "lti_bootstrap_token";

type TokenResponse = {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
};

export type AuthenticatedGetResult =
  | { kind: "ok"; response: Response; accessToken: string }
  | { kind: "unauthorized"; accessToken: string };

export async function authenticatedGet(
  path: string,
  currentAccessToken: string,
  signal: AbortSignal,
): Promise<AuthenticatedGetResult> {
  let accessToken = await ensureAccessToken(currentAccessToken, signal);
  let response = await fetchWithAccessToken(path, accessToken, signal);

  if (response.status === 401) {
    accessToken = await refreshAccessToken(signal);
    response = await fetchWithAccessToken(path, accessToken, signal);
  }

  if (response.status === 401) {
    return { kind: "unauthorized", accessToken };
  }

  return { kind: "ok", response, accessToken };
}

async function ensureAccessToken(
  currentAccessToken: string,
  signal: AbortSignal,
): Promise<string> {
  if (currentAccessToken.length > 0) {
    return currentAccessToken;
  }

  const existingRefreshToken = sessionStorage.getItem(REFRESH_TOKEN_KEY);
  if (existingRefreshToken !== null && existingRefreshToken.length > 0) {
    return refreshAccessToken(signal);
  }

  const bootstrapToken = sessionStorage.getItem(BOOTSTRAP_TOKEN_KEY);
  if (bootstrapToken === null || bootstrapToken.length === 0) {
    throw new Error("Missing bootstrap token. Please relaunch the tool.");
  }

  const tokenResponse = await requestToken(
    {
      grant_type: "bootstrap",
      bootstrap_token: bootstrapToken,
    },
    signal,
  );

  sessionStorage.removeItem(BOOTSTRAP_TOKEN_KEY);
  sessionStorage.setItem(REFRESH_TOKEN_KEY, tokenResponse.refresh_token);

  return tokenResponse.access_token;
}

async function refreshAccessToken(signal: AbortSignal): Promise<string> {
  const refreshToken = sessionStorage.getItem(REFRESH_TOKEN_KEY);
  if (refreshToken === null || refreshToken.length === 0) {
    throw new Error("Missing refresh token. Please relaunch the tool.");
  }

  const tokenResponse = await requestToken(
    {
      grant_type: "refresh_token",
      refresh_token: refreshToken,
    },
    signal,
  );

  sessionStorage.setItem(REFRESH_TOKEN_KEY, tokenResponse.refresh_token);
  return tokenResponse.access_token;
}

async function fetchWithAccessToken(
  path: string,
  accessToken: string,
  signal: AbortSignal,
): Promise<Response> {
  return fetch(path, {
    method: "GET",
    signal,
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
  });
}

async function requestToken(
  params: Record<string, string>,
  signal: AbortSignal,
): Promise<TokenResponse> {
  const body = new URLSearchParams(params);

  const response = await fetch("/api/auth/token", {
    method: "POST",
    body,
    signal,
    headers: {
      Accept: "application/json",
      "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
    },
  });

  if (!response.ok) {
    throw new Error(`Token request failed with status ${response.status}`);
  }

  return (await response.json()) as TokenResponse;
}
