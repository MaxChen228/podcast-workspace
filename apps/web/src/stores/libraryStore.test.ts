import { afterEach, describe, expect, it } from "vitest";
import { act } from "@testing-library/react";
import { useLibraryStore } from "./libraryStore";

const store = useLibraryStore;

afterEach(() => {
  act(() => store.getState().clear());
});

describe("libraryStore", () => {
  it("adds and removes books", () => {
    act(() => store.getState().addBook({ id: "book-1", title: "Project Hail Mary" }));
    expect(Object.keys(store.getState().books)).toContain("book-1");

    act(() => store.getState().removeBook("book-1"));
    expect(store.getState().books).toEqual({});
  });

  it("toggles chapter completion", () => {
    act(() => store.getState().addBook({ id: "book-2", title: "Dune" }));
    act(() => store.getState().toggleChapterCompletion("book-2", "chapter0"));
    expect(store.getState().books["book-2"].completedChapters["chapter0"]).toBe(true);
  });
});
