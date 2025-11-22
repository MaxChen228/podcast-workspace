import { useMemo } from "react";
import { ApiClient } from "../lib/apiClient";
import { useServerConfig } from "../providers/ServerConfigProvider";

export function useApiClient(): ApiClient {
  const { apiBaseUrl } = useServerConfig();
  return useMemo(() => new ApiClient(apiBaseUrl), [apiBaseUrl]);
}
