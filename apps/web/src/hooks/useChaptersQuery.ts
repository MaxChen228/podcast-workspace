import { useQuery } from "@tanstack/react-query";
import { useApiClient } from "./useApiClient";
import { useServerConfig } from "../providers/ServerConfigProvider";
import type { ChapterItem } from "../types/api";

export function useChaptersQuery(bookId: string | undefined, enabled = true) {
  const apiClient = useApiClient();
  const { apiBaseUrl } = useServerConfig();

  return useQuery<ChapterItem[]>({
    queryKey: ["chapters", apiBaseUrl, bookId],
    queryFn: ({ signal }) => {
      if (!bookId) throw new Error("bookId is required");
      return apiClient.fetchChapters(bookId, signal);
    },
    enabled: enabled && Boolean(bookId),
  });
}
