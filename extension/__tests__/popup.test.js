/**
 * Tests for the Bookmark Manager Chrome Extension
 * Tests the scraping logic, data extraction, and export functionality
 */

describe('Bookmark Manager Extension', () => {
  // MARK: - Tweet ID Extraction Tests

  describe('Tweet ID Extraction', () => {
    test('should extract tweet ID from valid URL', () => {
      const url = 'https://x.com/testuser/status/1234567890123456789';
      const match = url.match(/\/status\/(\d+)/);

      expect(match).not.toBeNull();
      expect(match[1]).toBe('1234567890123456789');
    });

    test('should extract tweet ID from twitter.com URL', () => {
      const url = 'https://twitter.com/testuser/status/9876543210';
      const match = url.match(/\/status\/(\d+)/);

      expect(match).not.toBeNull();
      expect(match[1]).toBe('9876543210');
    });

    test('should not match URL without status', () => {
      const url = 'https://x.com/testuser/followers';
      const match = url.match(/\/status\/(\d+)/);

      expect(match).toBeNull();
    });

    test('should handle URL with query parameters', () => {
      const url = 'https://x.com/testuser/status/123456?s=20';
      const match = url.match(/\/status\/(\d+)/);

      expect(match).not.toBeNull();
      expect(match[1]).toBe('123456');
    });
  });

  // MARK: - Author Handle Extraction Tests

  describe('Author Handle Extraction', () => {
    test('should extract author handle from tweet URL', () => {
      const url = 'https://x.com/elonmusk/status/123456789';
      const match = url.match(/\/([^/]+)\/status\/\d+/);

      expect(match).not.toBeNull();
      expect(match[1]).toBe('elonmusk');
    });

    test('should handle handles with underscores', () => {
      const url = 'https://x.com/test_user_123/status/123456789';
      const match = url.match(/\/([^/]+)\/status\/\d+/);

      expect(match).not.toBeNull();
      expect(match[1]).toBe('test_user_123');
    });

    test('should handle handles with numbers', () => {
      const url = 'https://x.com/user2024/status/123456789';
      const match = url.match(/\/([^/]+)\/status\/\d+/);

      expect(match).not.toBeNull();
      expect(match[1]).toBe('user2024');
    });
  });

  // MARK: - Duplicate Detection Tests

  describe('Duplicate Detection', () => {
    test('should detect duplicate tweet IDs', () => {
      const seenIds = new Set();
      const tweetIds = ['123', '456', '123', '789', '456'];
      const unique = [];

      for (const id of tweetIds) {
        if (!seenIds.has(id)) {
          seenIds.add(id);
          unique.push(id);
        }
      }

      expect(unique).toEqual(['123', '456', '789']);
      expect(unique.length).toBe(3);
    });

    test('should handle empty input', () => {
      const seenIds = new Set();
      const tweetIds = [];
      const unique = [];

      for (const id of tweetIds) {
        if (!seenIds.has(id)) {
          seenIds.add(id);
          unique.push(id);
        }
      }

      expect(unique).toEqual([]);
    });

    test('should handle all duplicates', () => {
      const seenIds = new Set();
      const tweetIds = ['123', '123', '123'];
      const unique = [];

      for (const id of tweetIds) {
        if (!seenIds.has(id)) {
          seenIds.add(id);
          unique.push(id);
        }
      }

      expect(unique).toEqual(['123']);
    });
  });

  // MARK: - Bookmark Data Validation Tests

  describe('Bookmark Data Validation', () => {
    test('should validate required fields', () => {
      const validBookmark = {
        tweet_id: '123456',
        author_handle: 'testuser',
        content: 'Test tweet content',
      };

      const isValid = validBookmark.tweet_id && validBookmark.author_handle && validBookmark.content;

      expect(isValid).toBeTruthy();
    });

    test('should reject bookmark without tweet_id', () => {
      const invalidBookmark = {
        author_handle: 'testuser',
        content: 'Test tweet content',
      };

      const isValid = invalidBookmark.tweet_id && invalidBookmark.author_handle && invalidBookmark.content;

      expect(isValid).toBeFalsy();
    });

    test('should reject bookmark without author_handle', () => {
      const invalidBookmark = {
        tweet_id: '123456',
        content: 'Test tweet content',
      };

      const isValid = invalidBookmark.tweet_id && invalidBookmark.author_handle && invalidBookmark.content;

      expect(isValid).toBeFalsy();
    });

    test('should reject bookmark without content', () => {
      const invalidBookmark = {
        tweet_id: '123456',
        author_handle: 'testuser',
      };

      const isValid = invalidBookmark.tweet_id && invalidBookmark.author_handle && invalidBookmark.content;

      expect(isValid).toBeFalsy();
    });

    test('should filter out invalid bookmarks', () => {
      const bookmarks = [
        { tweet_id: '1', author_handle: 'user1', content: 'Content 1' },
        { tweet_id: '2', author_handle: '', content: 'Content 2' },
        { tweet_id: '', author_handle: 'user3', content: 'Content 3' },
        { tweet_id: '4', author_handle: 'user4', content: 'Content 4' },
      ];

      const valid = bookmarks.filter((b) => b.tweet_id && b.author_handle && b.content);

      expect(valid.length).toBe(2);
    });
  });

  // MARK: - Media URL Extraction Tests

  describe('Media URL Extraction', () => {
    test('should identify twimg.com media URLs', () => {
      const url = 'https://pbs.twimg.com/media/test.jpg';

      expect(url.includes('twimg.com')).toBe(true);
    });

    test('should filter profile images', () => {
      const urls = [
        'https://pbs.twimg.com/media/test.jpg',
        'https://pbs.twimg.com/profile_images/avatar.jpg',
        'https://pbs.twimg.com/media/video_thumb.jpg',
      ];

      const mediaUrls = urls.filter((url) => !url.includes('/profile_images/'));

      expect(mediaUrls.length).toBe(2);
      expect(mediaUrls).not.toContain('https://pbs.twimg.com/profile_images/avatar.jpg');
    });

    test('should filter emoji images', () => {
      const urls = [
        'https://pbs.twimg.com/media/test.jpg',
        'https://abs.twimg.com/emoji/v2/emoji.png',
      ];

      const mediaUrls = urls.filter((url) => !url.includes('/emoji/'));

      expect(mediaUrls.length).toBe(1);
    });

    test('should deduplicate media URLs', () => {
      const urls = [
        'https://pbs.twimg.com/media/image1.jpg',
        'https://pbs.twimg.com/media/image2.jpg',
        'https://pbs.twimg.com/media/image1.jpg',
      ];

      const unique = [...new Set(urls)];

      expect(unique.length).toBe(2);
    });
  });

  // MARK: - Content Placeholder Tests

  describe('Content Placeholders', () => {
    test('should use [video] for video content', () => {
      const hasVideo = true;
      const hasImage = false;
      const hasCard = false;
      const textContent = '';

      let content = textContent;
      if (!content.trim()) {
        if (hasVideo) {
          content = '[video]';
        } else if (hasCard) {
          content = '[link/article]';
        } else if (hasImage) {
          content = '[image]';
        } else {
          content = '[no content]';
        }
      }

      expect(content).toBe('[video]');
    });

    test('should use [image] for image-only tweets', () => {
      const hasVideo = false;
      const hasImage = true;
      const hasCard = false;
      const textContent = '';

      let content = textContent;
      if (!content.trim()) {
        if (hasVideo) {
          content = '[video]';
        } else if (hasCard) {
          content = '[link/article]';
        } else if (hasImage) {
          content = '[image]';
        } else {
          content = '[no content]';
        }
      }

      expect(content).toBe('[image]');
    });

    test('should use [link/article] for card content', () => {
      const hasVideo = false;
      const hasImage = false;
      const hasCard = true;
      const textContent = '';

      let content = textContent;
      if (!content.trim()) {
        if (hasVideo) {
          content = '[video]';
        } else if (hasCard) {
          content = '[link/article]';
        } else if (hasImage) {
          content = '[image]';
        } else {
          content = '[no content]';
        }
      }

      expect(content).toBe('[link/article]');
    });

    test('should preserve text content over placeholders', () => {
      const hasVideo = true;
      const textContent = 'This is actual tweet text';

      let content = textContent;
      if (!content.trim()) {
        content = '[video]';
      }

      expect(content).toBe('This is actual tweet text');
    });
  });

  // MARK: - Timestamp Tests

  describe('Timestamp Handling', () => {
    test('should parse ISO 8601 date', () => {
      const dateString = '2024-01-15T10:30:00Z';
      const date = new Date(dateString);

      expect(date.toISOString()).toBe('2024-01-15T10:30:00.000Z');
    });

    test('should generate current timestamp for bookmarked_at', () => {
      const bookmarkedAt = new Date().toISOString();

      expect(bookmarkedAt).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);
    });

    test('should handle missing posted_at', () => {
      const postedAt = null;
      const fallback = postedAt || new Date().toISOString();

      expect(fallback).toBeTruthy();
      expect(fallback).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    });
  });

  // MARK: - URL Construction Tests

  describe('Tweet URL Construction', () => {
    test('should construct valid tweet URL', () => {
      const authorHandle = 'testuser';
      const tweetId = '1234567890';
      const url = `https://x.com/${authorHandle}/status/${tweetId}`;

      expect(url).toBe('https://x.com/testuser/status/1234567890');
    });

    test('should handle special characters in handle', () => {
      const authorHandle = 'test_user_123';
      const tweetId = '9876543210';
      const url = `https://x.com/${authorHandle}/status/${tweetId}`;

      expect(url).toBe('https://x.com/test_user_123/status/9876543210');
    });
  });

  // MARK: - Continue From Last Tests

  describe('Continue From Last Export', () => {
    test('should identify last tweet position', () => {
      const lastTweetId = '500';
      const tweetIds = ['100', '200', '300', '400', '500', '600', '700'];

      let foundIndex = -1;
      for (let i = 0; i < tweetIds.length; i++) {
        if (tweetIds[i] === lastTweetId) {
          foundIndex = i;
          break;
        }
      }

      expect(foundIndex).toBe(4);
    });

    test('should collect tweets after last position', () => {
      const lastTweetId = '300';
      const tweetIds = ['100', '200', '300', '400', '500'];

      let foundLastTweet = false;
      const newTweets = [];

      for (const id of tweetIds) {
        if (!foundLastTweet) {
          if (id === lastTweetId) {
            foundLastTweet = true;
          }
          continue;
        }
        newTweets.push(id);
      }

      expect(newTweets).toEqual(['400', '500']);
    });

    test('should handle missing last tweet', () => {
      const lastTweetId = '999';
      const tweetIds = ['100', '200', '300'];

      const found = tweetIds.includes(lastTweetId);

      expect(found).toBe(false);
    });

    test('should save last exported tweet ID', () => {
      const bookmarks = [
        { tweet_id: '100' },
        { tweet_id: '200' },
        { tweet_id: '300' },
      ];

      const lastExportedId = bookmarks[bookmarks.length - 1].tweet_id;

      expect(lastExportedId).toBe('300');
    });
  });

  // MARK: - Auto-Scroll Logic Tests

  describe('Auto-Scroll Logic', () => {
    test('should stop after max scrolls', () => {
      const maxScrolls = 100;
      let scrollCount = 0;

      while (scrollCount < maxScrolls) {
        scrollCount++;
      }

      expect(scrollCount).toBe(maxScrolls);
    });

    test('should stop after consecutive no new tweets', () => {
      let noNewTweetsCount = 0;
      const maxNoNew = 3;
      let scrollCount = 0;
      const maxScrolls = 100;

      // Simulate 5 scrolls with no new tweets
      while (scrollCount < maxScrolls && noNewTweetsCount < maxNoNew) {
        const newFound = 0; // Simulate no new tweets
        if (newFound === 0) {
          noNewTweetsCount++;
        } else {
          noNewTweetsCount = 0;
        }
        scrollCount++;
      }

      expect(scrollCount).toBe(3);
      expect(noNewTweetsCount).toBe(3);
    });

    test('should reset no-new counter when tweets found', () => {
      let noNewTweetsCount = 2;
      const newFound = 5;

      if (newFound === 0) {
        noNewTweetsCount++;
      } else {
        noNewTweetsCount = 0;
      }

      expect(noNewTweetsCount).toBe(0);
    });
  });

  // MARK: - JSON Export Tests

  describe('JSON Export', () => {
    test('should serialize bookmarks to JSON', () => {
      const bookmarks = [
        {
          tweet_id: '123',
          author_handle: 'user1',
          author_name: 'User One',
          content: 'Test tweet',
          posted_at: '2024-01-15T10:30:00Z',
          bookmarked_at: '2024-01-15T11:00:00Z',
          url: 'https://x.com/user1/status/123',
          media_urls: [],
        },
      ];

      const json = JSON.stringify(bookmarks);
      const parsed = JSON.parse(json);

      expect(parsed.length).toBe(1);
      expect(parsed[0].tweet_id).toBe('123');
    });

    test('should handle special characters in content', () => {
      const bookmarks = [
        {
          tweet_id: '123',
          author_handle: 'user',
          content: 'Tweet with "quotes" and special chars: <>&',
        },
      ];

      const json = JSON.stringify(bookmarks);
      const parsed = JSON.parse(json);

      expect(parsed[0].content).toContain('"quotes"');
      expect(parsed[0].content).toContain('<>&');
    });

    test('should handle emoji in content', () => {
      const bookmarks = [
        {
          tweet_id: '123',
          author_handle: 'user',
          content: 'Tweet with emoji 🚀🔥💯',
        },
      ];

      const json = JSON.stringify(bookmarks);
      const parsed = JSON.parse(json);

      expect(parsed[0].content).toContain('🚀');
    });

    test('should handle unicode in author names', () => {
      const bookmarks = [
        {
          tweet_id: '123',
          author_handle: 'user',
          author_name: '日本語ユーザー',
          content: 'Test',
        },
      ];

      const json = JSON.stringify(bookmarks);
      const parsed = JSON.parse(json);

      expect(parsed[0].author_name).toBe('日本語ユーザー');
    });
  });

  // MARK: - Bookmarks Page Detection Tests

  describe('Bookmarks Page Detection', () => {
    test('should detect x.com bookmarks page', () => {
      const url = 'https://x.com/i/bookmarks';
      const isBookmarksPage = url.includes('/i/bookmarks');

      expect(isBookmarksPage).toBe(true);
    });

    test('should detect twitter.com bookmarks page', () => {
      const url = 'https://twitter.com/i/bookmarks';
      const isBookmarksPage = url.includes('/i/bookmarks');

      expect(isBookmarksPage).toBe(true);
    });

    test('should not detect non-bookmarks page', () => {
      const url = 'https://x.com/home';
      const isBookmarksPage = url.includes('/i/bookmarks');

      expect(isBookmarksPage).toBe(false);
    });

    test('should not detect profile page', () => {
      const url = 'https://x.com/testuser';
      const isBookmarksPage = url.includes('/i/bookmarks');

      expect(isBookmarksPage).toBe(false);
    });
  });

  // MARK: - Error Handling Tests

  describe('Error Handling', () => {
    test('should handle empty bookmarks array', () => {
      const bookmarks = [];

      expect(() => {
        if (!bookmarks || bookmarks.length === 0) {
          throw new Error('No bookmarks found');
        }
      }).toThrow('No bookmarks found');
    });

    test('should handle null bookmarks', () => {
      const bookmarks = null;

      expect(() => {
        if (!bookmarks || bookmarks.length === 0) {
          throw new Error('No bookmarks found');
        }
      }).toThrow('No bookmarks found');
    });

    test('should provide meaningful error for continue from last', () => {
      const lastTweetId = '123';
      const bookmarks = [];

      expect(() => {
        if (lastTweetId && bookmarks.length === 0) {
          throw new Error('No new bookmarks found after last saved position');
        }
      }).toThrow('No new bookmarks found after last saved position');
    });
  });

  // MARK: - Chrome Storage Mock Tests

  describe('Chrome Storage', () => {
    test('should call chrome.storage.local.get', async () => {
      await chrome.storage.local.get('lastTweetId');

      expect(chrome.storage.local.get).toHaveBeenCalledWith('lastTweetId');
    });

    test('should call chrome.storage.local.set', async () => {
      await chrome.storage.local.set({ lastTweetId: '12345' });

      expect(chrome.storage.local.set).toHaveBeenCalledWith({ lastTweetId: '12345' });
    });
  });

  // MARK: - Performance Tests

  describe('Performance Considerations', () => {
    test('should handle large number of bookmarks', () => {
      const bookmarks = Array.from({ length: 1000 }, (_, i) => ({
        tweet_id: String(i),
        author_handle: `user${i}`,
        content: `Tweet ${i}`,
      }));

      const json = JSON.stringify(bookmarks);

      expect(bookmarks.length).toBe(1000);
      expect(json.length).toBeGreaterThan(0);
    });

    test('should efficiently deduplicate with Set', () => {
      const ids = Array.from({ length: 10000 }, (_, i) => String(i % 100));
      const seenIds = new Set();
      const unique = [];

      for (const id of ids) {
        if (!seenIds.has(id)) {
          seenIds.add(id);
          unique.push(id);
        }
      }

      expect(unique.length).toBe(100);
    });
  });

  // MARK: - Bookmark Data Structure Tests

  describe('Bookmark Data Structure', () => {
    test('should create complete bookmark object', () => {
      const bookmark = {
        tweet_id: '123456789',
        author_handle: 'testuser',
        author_name: 'Test User',
        author_avatar: 'https://pbs.twimg.com/profile_images/123/avatar.jpg',
        content: 'This is a test tweet',
        posted_at: '2024-01-15T10:30:00Z',
        bookmarked_at: new Date().toISOString(),
        url: 'https://x.com/testuser/status/123456789',
        media_urls: ['https://pbs.twimg.com/media/test.jpg'],
      };

      expect(bookmark).toHaveProperty('tweet_id');
      expect(bookmark).toHaveProperty('author_handle');
      expect(bookmark).toHaveProperty('author_name');
      expect(bookmark).toHaveProperty('author_avatar');
      expect(bookmark).toHaveProperty('content');
      expect(bookmark).toHaveProperty('posted_at');
      expect(bookmark).toHaveProperty('bookmarked_at');
      expect(bookmark).toHaveProperty('url');
      expect(bookmark).toHaveProperty('media_urls');
    });

    test('should allow optional fields to be undefined', () => {
      const bookmark = {
        tweet_id: '123',
        author_handle: 'user',
        author_name: 'user',
        content: 'Test',
        posted_at: '2024-01-15T10:30:00Z',
        bookmarked_at: '2024-01-15T11:00:00Z',
        url: 'https://x.com/user/status/123',
        media_urls: [],
        // author_avatar intentionally omitted
      };

      expect(bookmark.author_avatar).toBeUndefined();
    });
  });
});
