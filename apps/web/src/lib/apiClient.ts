import type { BookItem, ChapterItem } from "../types/api";

type FetchOptions = Omit<RequestInit, "body"> & { body?: Record<string, unknown> };

export class ApiClient {
  constructor(private readonly baseUrl: string) { }

  private buildUrl(path: string): string {
    if (!this.baseUrl) {
      throw new Error("API base URL is not configured");
    }
    const normalizedPath = path.startsWith("/") ? path : `/${path}`;
    return `${this.baseUrl}${normalizedPath}`;
  }

  private async request<T>(path: string, options?: FetchOptions): Promise<T> {
    const url = this.buildUrl(path);
    const headers: Record<string, string> = {
      Accept: "application/json",
      ...(options?.headers as Record<string, string> | undefined),
    };

    const response = await fetch(url, {
      ...options,
      headers,
      body: options?.body ? JSON.stringify(options.body) : undefined,
    });

    if (!response.ok) {
      const message = await response.text();
      throw new Error(message || `Request failed with ${response.status}`);
    }

    return response.json() as Promise<T>;
  }

  fetchBooks(signal?: AbortSignal) {
    return this.request<BookItem[]>("/books", { signal });
  }

  fetchChapters(bookId: string, signal?: AbortSignal) {
    return this.request<ChapterItem[]>(`/books/${encodeURIComponent(bookId)}/chapters`, { signal });
  }
}
