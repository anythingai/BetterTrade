import "@testing-library/jest-dom";
import { configure } from "@testing-library/react";

// Configure testing library
configure({
  asyncUtilTimeout: 5000,
});

// Suppress specific React warnings in tests
// eslint-disable-next-line no-console
const originalError = console.error;

beforeEach(() => {
  // eslint-disable-next-line no-console
  console.error = (...args: unknown[]) => {
    if (
      typeof args[0] === "string" &&
      (args[0].includes("ReactDOMTestUtils.act") ||
        args[0].includes("Warning: An update to") ||
        args[0].includes("not wrapped in act"))
    ) {
      return;
    }
    originalError.call(console, ...args);
  };
});

afterEach(() => {
  // eslint-disable-next-line no-console
  console.error = originalError;
});

// Mock IntersectionObserver
global.IntersectionObserver = class IntersectionObserver {
  root: Element | null = null;
  rootMargin: string = "0px";
  thresholds: ReadonlyArray<number> = [];

  constructor(
    _callback: IntersectionObserverCallback,
    _options?: IntersectionObserverInit
  ) {}
  disconnect() {}
  observe() {}
  unobserve() {}
  takeRecords(): IntersectionObserverEntry[] {
    return [];
  }
} as unknown as typeof IntersectionObserver;

// Mock ResizeObserver
global.ResizeObserver = class ResizeObserver {
  constructor() {}
  disconnect() {}
  observe() {}
  unobserve() {}
};
