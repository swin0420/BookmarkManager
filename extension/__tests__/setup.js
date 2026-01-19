// Mock Chrome API
global.chrome = {
  storage: {
    local: {
      get: jest.fn((keys) => Promise.resolve({})),
      set: jest.fn(() => Promise.resolve()),
    },
  },
  tabs: {
    query: jest.fn(() => Promise.resolve([{ url: 'https://x.com/i/bookmarks', id: 1 }])),
  },
  scripting: {
    executeScript: jest.fn(() => Promise.resolve([{ result: [] }])),
  },
};

// Mock URL API
global.URL = {
  createObjectURL: jest.fn(() => 'blob:test-url'),
  revokeObjectURL: jest.fn(),
};

// Mock document methods for download functionality
Object.defineProperty(document, 'createElement', {
  value: jest.fn((tagName) => {
    const element = {
      tagName,
      href: '',
      download: '',
      click: jest.fn(),
      style: {},
      appendChild: jest.fn(),
      removeChild: jest.fn(),
    };
    return element;
  }),
});

Object.defineProperty(document.body, 'appendChild', {
  value: jest.fn(),
  writable: true,
});

Object.defineProperty(document.body, 'removeChild', {
  value: jest.fn(),
  writable: true,
});

// Mock Blob
global.Blob = jest.fn((content, options) => ({
  content,
  type: options?.type || 'application/octet-stream',
}));

// Reset all mocks before each test
beforeEach(() => {
  jest.clearAllMocks();
});
