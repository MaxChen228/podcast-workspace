import { useQuery } from "@tanstack/react-query";
import { useApiClient } from "./useApiClient";
import { useServerConfig } from "../providers/ServerConfigProvider";
import type { BookItem } from "../types/api";

export function useBooksQuery() {
  const apiClient = useApiClient();
  const { apiBaseUrl } = useServerConfig();

  return useQuery<BookItem[]>({
    queryKey: ["books", apiBaseUrl],
    queryFn: ({ signal }) => apiClient.fetchBooks(signal),
  });
}
