import { create } from "zustand";

export type LibraryBook = {
  id: string;
  title: string;
  coverUrl?: string;
  addedAt: string;
  completedChapters: Record<string, boolean>;
};

type LibraryState = {
  books: Record<string, LibraryBook>;
  addBook: (book: { id: string; title: string; coverUrl?: string }) => void;
  removeBook: (bookId: string) => void;
  clear: () => void;
  toggleChapterCompletion: (bookId: string, chapterId: string) => void;
};

const STORAGE_KEY = "ps-web-library-store";

const getBrowserStorage = () => {
  if (typeof window === "undefined") {
    return undefined;
  }
  try {
    const candidate = window.localStorage;
    if (candidate && typeof candidate.setItem === "function") {
      return candidate;
    }
    return undefined;
  } catch {
    return undefined;
  }
};

const loadInitialBooks = (): Record<string, LibraryBook> => {
  try {
    const storage = getBrowserStorage();
    if (!storage) {
      return {};
    }
    const raw = storage.getItem(STORAGE_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw) as Record<string, LibraryBook>;
    // Defensive: ensure all books have completedChapters
    Object.values(parsed).forEach((book) => {
      if (!book.completedChapters) {
        book.completedChapters = {};
      }
    });
    return parsed;
  } catch {
    return {};
  }
};

export const useLibraryStore = create<LibraryState>((set, get) => ({
  books: loadInitialBooks(),
  addBook: ({ id, title, coverUrl }) =>
    set((state) => {
      if (state.books[id]) {
        return state;
      }
      return {
        books: {
          ...state.books,
          [id]: {
            id,
            title,
            coverUrl,
            addedAt: new Date().toISOString(),
            completedChapters: {},
          },
        },
      };
    }),
  removeBook: (bookId) =>
    set((state) => {
      const next = { ...state.books };
      delete next[bookId];
      return { books: next };
    }),
  clear: () => set({ books: {} }),
  toggleChapterCompletion: (bookId, chapterId) =>
    set((state) => {
      const book = state.books[bookId];
      if (!book) return state;
      const nextCompleted = { ...book.completedChapters };
      nextCompleted[chapterId] = !nextCompleted[chapterId];
      return {
        books: {
          ...state.books,
          [bookId]: { ...book, completedChapters: nextCompleted },
        },
      };
    }),
}));

const storage = getBrowserStorage();
if (storage) {
  useLibraryStore.subscribe((state) => {
    try {
      storage.setItem(STORAGE_KEY, JSON.stringify(state.books));
    } catch (error) {
      console.warn("Failed to persist library store", error);
    }
  });
}

import { useShallow } from "zustand/react/shallow";

export function useLibraryList(): LibraryBook[] {
  return useLibraryStore(
    useShallow((state) =>
      Object.values(state.books).sort((a, b) => b.addedAt.localeCompare(a.addedAt))
    )
  );
}
